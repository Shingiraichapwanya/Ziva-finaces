/**
 * SlackFormatter.js - Slack Block Kit Formatter
 * Builds interactive and visually informative Block Kit payloads for Slack responses.
 * Compatible with Google Apps Script (V8 runtime) and Node.js.
 */

class SlackFormatter {
  /**
   * Format a successful transaction ingestion response.
   * @param {object} parsed Parsed transaction object from Parser.js
   * @param {object} result Result object from BigQueryClient.insertTransaction()
   * @param {object|null} budgetStatus Monthly budget comparison from BigQueryClient.getCategoryBudgetStatus()
   * @returns {object} Slack message payload with Block Kit blocks
   */
  static formatSuccessMessage(parsed, result, budgetStatus) {
    const isIncome = parsed.transactionType === 'INCOME';
    const originalAmt = Math.abs(parsed.originalAmount).toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });

    const headerText = isIncome
      ? `💰 Income Logged: +${originalAmt} ${parsed.originalCurrency}`
      : `💸 Expense Logged: -${originalAmt} ${parsed.originalCurrency}`;

    const blocks = [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: headerText,
          emoji: true
        }
      }
    ];

    // Primary detail section
    const zarAmt = Math.abs(result.record.reporting_amount_zar).toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
    const usdAmt = Math.abs(result.record.reporting_amount_usd).toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });

    const fields = [
      {
        type: 'mrkdwn',
        text: `*Original Amount:*\n\`${parsed.originalCurrency} ${originalAmt}\``
      },
      {
        type: 'mrkdwn',
        text: `*Converted Reporting:*\n\`R ${zarAmt}\` (≈ \`$ ${usdAmt}\`)`
      },
      {
        type: 'mrkdwn',
        text: `*Category:*\n📁 ${parsed.categoryName || parsed.categoryId} (\`${parsed.categoryId}\`)`
      },
      {
        type: 'mrkdwn',
        text: `*Account / Tier:*\n🏦 \`${parsed.accountId}\`\n🏷️ _${parsed.cashFlowTier}_`
      }
    ];

    if (parsed.merchantOrPayee) {
      fields.push({
        type: 'mrkdwn',
        text: `*Merchant / Payee:*\n🏪 ${parsed.merchantOrPayee}`
      });
    }

    if (parsed.isTaxDeductible) {
      fields.push({
        type: 'mrkdwn',
        text: '*Tax Treatment:*\n💼 `Tax-Deductible Business Expense` (Offset Eligible)'
      });
    } else if (parsed.categoryId === 'CAT_TAX_STATUTORY_PROVISIONAL') {
      fields.push({
        type: 'mrkdwn',
        text: '*Tax Treatment:*\n🏛️ `Statutory Tax Remittance` (Provisional Payment)'
      });
    }

    if (parsed.taxInvoiceNumber) {
      fields.push({
        type: 'mrkdwn',
        text: `*Invoice / Tax Ref:*\n🧾 \`${parsed.taxInvoiceNumber}\``
      });
    }

    if (parsed.notes) {
      fields.push({
        type: 'mrkdwn',
        text: `*Notes:*\n📝 ${parsed.notes}`
      });
    }

    blocks.push({
      type: 'section',
      fields: fields
    });

    // Budget Envelope Health Section (if available)
    if (budgetStatus) {
      blocks.push({ type: 'divider' });

      let statusEmoji = '🟢';
      let statusLabel = 'On Track';
      if (budgetStatus.budgetStatus === 'OVER_BUDGET' || budgetStatus.pctConsumed >= 100) {
        statusEmoji = '🔴';
        statusLabel = 'OVER BUDGET';
      } else if (budgetStatus.budgetStatus === 'NEAR_LIMIT' || budgetStatus.pctConsumed >= 80) {
        statusEmoji = '🟡';
        statusLabel = 'Near Limit';
      }

      const plannedZar = budgetStatus.plannedAmountZar.toLocaleString('en-US', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
      });
      const spentZar = budgetStatus.actualSpentZar.toLocaleString('en-US', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
      });
      const varianceZar = budgetStatus.varianceZar.toLocaleString('en-US', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
      });
      const pct = budgetStatus.pctConsumed;

      const progressIndicator = this._createProgressBar(pct);

      blocks.push({
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Budget Envelope Status:* ${statusEmoji} *${statusLabel}* (${pct}% consumed)\n${progressIndicator}\n• *Budget:* R ${plannedZar} | *Spent:* R ${spentZar} | *Remaining:* R ${varianceZar}`
        }
      });
    }

    // Footer context
    const modeBadge = result.jobId ? `Job: \`${result.jobId.slice(0, 16)}...\`` : (result.isMock ? '_Mock Mode_' : '_DML Insert_');
    blocks.push({
      type: 'context',
      elements: [
        {
          type: 'mrkdwn',
          text: `🆔 \`${result.transactionId}\` | ⏱️ ${result.record.transaction_timestamp} | ${modeBadge} | 📍 BigQuery \`personal_finance\``
        }
      ]
    });

    return {
      response_type: 'in_channel',
      blocks: blocks
    };
  }

  /**
   * Format an error message into a user-friendly Slack Block Kit response.
   * @param {string} errorMessage Description of what went wrong
   * @param {string} rawInput The original text submitted by the user
   * @returns {object} Slack message payload
   */
  static formatErrorMessage(errorMessage, rawInput) {
    return {
      response_type: 'ephemeral',
      blocks: [
        {
          type: 'header',
          text: {
            type: 'plain_text',
            text: '⚠️ Could Not Log Transaction',
            emoji: true
          }
        },
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: `*Error:* ${errorMessage}\n\n*Input Received:* \`${rawInput || '(empty)'}\``
          }
        },
        {
          type: 'divider'
        },
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: '*Try one of these examples:*\n• `/spend 50 ZAR lunch at Vida`\n• `/spend Paid 120 USD for OK Mart groceries`\n• `/spend R45 coffee`\n• `/spend 245 ZiG airtime Econet`\n• `/spend Rent 14500 ZAR`\n• `/spend Salary received 55000 ZAR`'
          }
        }
      ]
    };
  }

  /**
   * Format a comprehensive help message for Slack.
   * @returns {object} Slack message payload
   */
  static formatHelpMessage() {
    return {
      response_type: 'ephemeral',
      blocks: [
        {
          type: 'header',
          text: {
            type: 'plain_text',
            text: '🤖 Personal Finance Budget Bot - Help & Quick Reference',
            emoji: true
          }
        },
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: 'Log your transactions directly into **BigQuery** using natural language via `/spend` or mentioning the bot.'
          }
        },
        {
          type: 'divider'
        },
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: '*Supported Currencies:*\n' +
                  '• *ZAR (R)*: `R50`, `50 ZAR`, `50zar` (Mapped to SA Capitec / FNB accounts)\n' +
                  '• *USD ($)*: `$120`, `120 USD`, `120usd` (Mapped to ZW EcoCash USD / Stanbic Nostro)\n' +
                  '• *ZiG*: `245 ZiG`, `245zig` (Mapped to ZW EcoCash ZiG with parallel market FX normalization)'
          }
        },
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: '*Example Commands:*\n' +
                  '🍔 *Dining:* `/spend Spent 50 ZAR on lunch at Vida`\n' +
                  '🛒 *Groceries:* `/spend Paid 120 USD for OK Mart groceries`\n' +
                  '💻 *Tech Hardware:* `/spend Bought 7500 ZAR Dell 4K monitor for work invoice INV-9921`\n' +
                  '🤖 *AI & SaaS Tools:* `/spend Paid 40 USD for Claude and ChatGPT team`\n' +
                  '🏛️ *Tax Payment:* `/spend Paid 12000 ZAR provisional tax SARS ref SARS-2026-Q1`\n' +
                  '⛽ *Transport:* `/spend 150 ZAR Uber ride home`\n' +
                  '📱 *Airtime:* `/spend 245 ZiG airtime Econet`\n' +
                  '⚡ *Utilities:* `/spend 100 USD for ZESA token`\n' +
                  '🏠 *Fixed Bills:* `/spend Rent 14500 ZAR apartment lease`\n' +
                  '📈 *Investments:* `/spend Invested 8000 ZAR in S&P500 ETF`\n' +
                  '💰 *Income:* `/spend Salary received 55000 ZAR client retainer`'
          }
        },
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: '*Multi-Tier Account Routing:*\n' +
                  '• *Tier 1: Daily Spending* (Capitec ZAR / EcoCash USD & ZiG)\n' +
                  '• *Tier 2: Monthly Allocations* (FNB ZAR / Stanbic Nostro USD)\n' +
                  '• *Tier 3: Vault / Investments* (EasyEquities ZAR / Old Mutual USD)'
          }
        },
        {
          type: 'context',
          elements: [
            {
              type: 'mrkdwn',
              text: '💡 All amounts are automatically converted to both USD and ZAR using live warehouse FX rates.'
            }
          ]
        }
      ]
    };
  }

  /**
   * Helper to create a visual progress bar.
   * @param {number} percentage
   * @returns {string} Text progress bar
   */
  static _createProgressBar(percentage) {
    const totalBars = 10;
    const filledBars = Math.min(totalBars, Math.max(0, Math.round((percentage / 100) * totalBars)));
    const emptyBars = totalBars - filledBars;

    let barChar = '█';
    if (percentage > 100) {
      barChar = '🟥';
    } else if (percentage >= 80) {
      barChar = '🟨';
    } else {
      barChar = '🟩';
    }

    return `${barChar.repeat(filledBars)}${'░'.repeat(emptyBars)}`;
  }
}

// CommonJS export for testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { SlackFormatter };
}
