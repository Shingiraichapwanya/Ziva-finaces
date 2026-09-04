/**
 * Code.js - Google Apps Script Web App Entry Point
 * Handles Slack Slash Commands (/spend) and Bot Mentions/Events,
 * coordinates parsing, BigQuery ingestion, and Block Kit responses.
 */

/**
 * HTTP GET Handler - Health Check & Diagnostics
 */
function doGet(e) {
  const status = {
    status: 'HEALTHY',
    service: 'BigQuery Personal Finance Slack Ingestion Engine',
    projectId: BQ_CONFIG.projectId,
    dataset: BQ_CONFIG.datasetId,
    location: BQ_CONFIG.location,
    serverTime: new Date().toISOString(),
    supportedCurrencies: ['ZAR', 'USD', 'ZiG'],
    version: '1.0.0'
  };

  return ContentService
    .createTextOutput(JSON.stringify(status, null, 2))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * HTTP POST Handler - Slack Slash Commands & Event Callbacks
 */
function doPost(e) {
  try {
    // 1. Check for Slack URL Verification Challenge (Event Subscriptions handshake)
    if (e.postData && e.postData.type === 'application/json') {
      const payload = JSON.parse(e.postData.contents);
      if (payload.type === 'url_verification') {
        return ContentService
          .createTextOutput(payload.challenge)
          .setMimeType(ContentService.MimeType.TEXT);
      }

      // Handle Slack Event API callbacks (e.g. app_mention)
      if (payload.event && (payload.event.type === 'app_mention' || payload.event.type === 'message')) {
        return handleSlackEvent(payload);
      }
    }

    // 2. Handle Slash Command (application/x-www-form-urlencoded)
    const params = e.parameter || {};
    const rawText = (params.text || '').trim();
    const userName = params.user_name || 'slack_user';
    const userId = params.user_id || '';

    // Check for help flag
    if (!rawText || rawText.toLowerCase() === 'help' || rawText.toLowerCase() === '--help') {
      const helpMsg = SlackFormatter.formatHelpMessage();
      return ContentService
        .createTextOutput(JSON.stringify(helpMsg))
        .setMimeType(ContentService.MimeType.JSON);
    }

    // 3. Process Transaction Text
    const responsePayload = processTransaction(rawText, {
      source: 'slash_command',
      userName: userName,
      userId: userId
    });

    return ContentService
      .createTextOutput(JSON.stringify(responsePayload))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    console.error('Unhandled doPost error:', error);
    const errorPayload = SlackFormatter.formatErrorMessage(
      `Internal processing error: ${error.message}`,
      e.parameter ? e.parameter.text : ''
    );
    return ContentService
      .createTextOutput(JSON.stringify(errorPayload))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * Handle Slack Event Subscriptions (e.g., bot mentions like @BudgetBot 50 ZAR lunch)
 */
function handleSlackEvent(payload) {
  const event = payload.event;
  // Ignore bot messages to prevent infinite loops
  if (event.bot_id || event.subtype === 'bot_message') {
    return ContentService.createTextOutput(JSON.stringify({ ok: true })).setMimeType(ContentService.MimeType.JSON);
  }

  // Strip bot mention tag <@U12345> from the text
  let rawText = (event.text || '').replace(/<@[A-Z0-9]+>/g, '').trim();

  if (!rawText || rawText.toLowerCase() === 'help') {
    const helpMsg = SlackFormatter.formatHelpMessage();
    sendSlackChatReply(event.channel, helpMsg);
    return ContentService.createTextOutput(JSON.stringify({ ok: true })).setMimeType(ContentService.MimeType.JSON);
  }

  const responsePayload = processTransaction(rawText, {
    source: 'bot_mention',
    userId: event.user,
    channelId: event.channel
  });

  // Post back to the Slack channel
  sendSlackChatReply(event.channel, responsePayload);

  return ContentService.createTextOutput(JSON.stringify({ ok: true })).setMimeType(ContentService.MimeType.JSON);
}

/**
 * Core business logic: parse natural language, ingest to BigQuery, return Block Kit message.
 * @param {string} text Raw natural language input
 * @param {object} context Slack user/channel metadata
 * @returns {object} Slack Block Kit response
 */
function processTransaction(text, context) {
  // Step 1: Parse natural language input
  let parseResult;
  try {
    parseResult = Parser.parse(text);
  } catch (err) {
    return SlackFormatter.formatErrorMessage(err.message, text);
  }

  if (!parseResult || !parseResult.success) {
    return SlackFormatter.formatErrorMessage(parseResult ? parseResult.error : 'Failed to parse input', text);
  }

  const parsed = parseResult.data;

  // Attach Slack context to metadata
  parsed.tags.push('slack');
  parsed.metadata = {
    source: context.source || 'slack',
    slack_user: context.userName || context.userId || 'anonymous',
    raw_prompt: text,
    ingested_at: new Date().toISOString()
  };

  // Step 2: Ingest into BigQuery fct_transactions
  const result = BigQueryClient.insertTransaction(parsed);
  if (!result.success) {
    return SlackFormatter.formatErrorMessage(result.error || 'Failed to insert into BigQuery.', text);
  }

  // Step 3: Query category budget envelope status for real-time feedback
  let budgetStatus = null;
  try {
    budgetStatus = BigQueryClient.getCategoryBudgetStatus(parsed.categoryId);
  } catch (e) {
    console.warn('Could not retrieve category budget status:', e);
  }

  // Step 4: Build rich Slack Block Kit confirmation
  return SlackFormatter.formatSuccessMessage(parsed, result, budgetStatus);
}

/**
 * Helper to post message back to Slack when responding to Event API callbacks.
 * Requires Slack Bot User OAuth Token stored in Script Properties if using Event API.
 */
function sendSlackChatReply(channel, payload) {
  const token = PropertiesService.getScriptProperties().getProperty('SLACK_BOT_TOKEN');
  if (!token) {
    console.warn('SLACK_BOT_TOKEN not configured in Script Properties; cannot send async chat reply.');
    return;
  }

  const url = 'https://slack.com/api/chat.postMessage';
  const options = {
    method: 'post',
    contentType: 'application/json; charset=utf-8',
    headers: {
      Authorization: `Bearer ${token}`
    },
    payload: JSON.stringify({
      channel: channel,
      blocks: payload.blocks,
      text: payload.blocks && payload.blocks[0] && payload.blocks[0].text ? payload.blocks[0].text.text : 'Transaction Logged'
    }),
    muteHttpExceptions: true
  };

  UrlFetchApp.fetch(url, options);
}

// CommonJS export for testing
if (typeof module !== 'undefined' && module.exports) {
  if (typeof Parser === 'undefined') {
    var { Parser } = require('./Parser');
  }
  if (typeof BigQueryClient === 'undefined') {
    var { BigQueryClient } = require('./BigQueryClient');
  }
  if (typeof SlackFormatter === 'undefined') {
    var { SlackFormatter } = require('./SlackFormatter');
  }
  module.exports = { doGet, doPost, processTransaction };
}

