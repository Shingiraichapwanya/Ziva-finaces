/**
 * GmailParser.js - Automated Gmail Receipt & Invoice Ingestion Engine
 * 
 * Scans incoming Gmail emails for financial keywords:
 * 'invoice', 'receipt', 'payment confirmation', 'payment advice'
 * Extracts PDF attachments, uploads them to Google Cloud Storage (GCS),
 * and ingests structured transactions into BigQuery fct_transactions.
 * 
 * Compatible with Google Apps Script (V8 runtime) and Node.js (via mock adapters).
 */

const GMAIL_CONFIG = {
  // Broadened keyword search query scanning all senders
  defaultQuery: 'has:attachment filename:pdf (invoice OR receipt OR "payment confirmation" OR "payment advice") -label:ZivaBudget/Processed',
  processedLabelName: 'ZivaBudget/Processed',
  defaultBucketName: 'budget-tracker-507418-receipts',
  maxThreadsPerRun: 20
};

class GmailReceiptParser {
  /**
   * Main entry point for time-driven triggers.
   * Scans Gmail inbox for receipt/invoice emails, archives PDFs to GCS, and ingests to BigQuery.
   * @param {string} [customQuery] Optional search query override
   * @param {number} [maxThreads] Optional max threads override
   * @returns {Array<object>} List of ingested transaction results
   */
  static scanIncomingReceipts(customQuery, maxThreads) {
    const query = customQuery || GMAIL_CONFIG.defaultQuery;
    const limit = maxThreads || GMAIL_CONFIG.maxThreadsPerRun;
    console.log(`[GmailParser] Initiating inbox scan with query: "${query}", maxThreads: ${limit}`);

    // In Apps Script environment, retrieve or create processed label
    let processedLabel = null;
    if (typeof GmailApp !== 'undefined') {
      processedLabel = this._getOrCreateLabel(GMAIL_CONFIG.processedLabelName);
    }

    const threads = typeof GmailApp !== 'undefined'
      ? GmailApp.search(query, 0, limit)
      : [];

    console.log(`[GmailParser] Found ${threads.length} matching email threads.`);
    const results = [];

    for (let t = 0; t < threads.length; t++) {
      const thread = threads[t];
      const messages = thread.getMessages();

      for (let m = 0; m < messages.length; m++) {
        const message = messages[m];
        const attachments = message.getAttachments();

        for (let a = 0; a < attachments.length; a++) {
          const attachment = attachments[a];
          if (!this.isPdfAttachment(attachment)) continue;

          try {
            const ingestedTx = this.processReceiptAttachment(message, attachment);
            if (ingestedTx && ingestedTx.success) {
              results.push(ingestedTx);
            }
          } catch (err) {
            console.error(`[GmailParser] Error processing attachment ${attachment.getName()}:`, err);
          }
        }
      }

      // Mark thread as processed to prevent duplicate ingestion
      if (processedLabel) {
        thread.addLabel(processedLabel);
      }
    }

    console.log(`[GmailParser] Finished run. Successfully ingested ${results.length} receipts.`);
    return results;
  }

  /**
   * Retrospective sweep from January 1st, 2026 to today.
   * Scans both incoming vendor receipts/invoices and outgoing invoices sent to clients.
   * @param {string} [startDate='2026/01/01'] Start date filter (YYYY/MM/DD)
   * @param {number} [maxThreads=100] Maximum threads to process
   * @returns {Array<object>} List of ingested transaction results
   */
  static runHistoricalSweep(startDate = '2026/01/01', maxThreads = 100) {
    const historicalQuery = `after:${startDate} has:attachment filename:pdf (invoice OR receipt OR "payment confirmation" OR "payment advice" OR "tax invoice" OR statement OR "client invoice") -label:ZivaBudget/Processed`;
    console.log(`[GmailParser] Running historical retrospective sweep with query: "${historicalQuery}", limit: ${maxThreads}`);
    return this.scanIncomingReceipts(historicalQuery, maxThreads);
  }

  /**
   * Determines if an attachment is a PDF document
   * @param {object} attachment GmailAttachment or mock
   * @returns {boolean}
   */
  static isPdfAttachment(attachment) {
    if (!attachment) return false;
    const name = (attachment.getName() || '').toLowerCase();
    const contentType = (attachment.getContentType() || '').toLowerCase();
    return name.endsWith('.pdf') || contentType.includes('pdf');
  }

  /**
   * Processes a single PDF receipt attachment:
   * 1. Extracts metadata and entities (Date, Merchant, Amount, Currency, Tax Ref)
   * 2. Uploads PDF to Google Cloud Storage
   * 3. Ingests into BigQuery with direct GCS download audit link
   * @param {object} message GmailMessage or mock
   * @param {object} attachment GmailAttachment or mock
   * @returns {object} Ingestion result
   */
  static processReceiptAttachment(message, attachment) {
    const rawDate = message.getDate ? message.getDate() : new Date();
    const dateStr = rawDate.toISOString().split('T')[0];
    const yearMonth = dateStr.substring(0, 7); // YYYY-MM
    const subject = message.getSubject ? message.getSubject() : '';
    const fromStr = message.getFrom ? message.getFrom() : '';
    const bodyText = message.getPlainBody ? message.getPlainBody() : '';
    const fileName = attachment.getName() || 'Receipt.pdf';

    // 1. Extract financial entities from combined subject, body, and filename
    const extraction = this.extractFinancialData({
      from: fromStr,
      subject: subject,
      bodyText: bodyText,
      fileName: fileName,
      dateStr: dateStr
    });

    // 2. Generate unique Transaction ID
    const randomSuffix = Math.floor(1000 + Math.random() * 9000);
    const txId = `TX_GMAIL_${dateStr.replace(/-/g, '')}_${randomSuffix}`;

    // 3. Upload PDF to Google Cloud Storage
    const bucketName = this.getGcsBucketName();
    const sanitizedFileName = fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
    const objectKey = `receipts/${yearMonth}/${txId}_${sanitizedFileName}`;
    const gcsResult = this.uploadPdfToGcs(attachment, objectKey, bucketName);
    const receiptUrl = gcsResult.publicUrl || `https://storage.googleapis.com/${bucketName}/${objectKey}`;

    // 4. Map account based on currency
    let accountId = 'ACC_ZA_CAPITEC_DAILY';
    if (extraction.currency === 'USD') {
      accountId = 'ACC_ZW_ECOCASH_USD';
    } else if (extraction.currency === 'ZiG') {
      accountId = 'ACC_ZW_ECOCASH_ZIG';
    }

    // 5. Construct transaction record (differentiate incoming expenses vs outgoing client invoices)
    const isOutgoing = extraction.isOutgoingClientInvoice;
    const originalAmount = isOutgoing ? Math.abs(extraction.amount) : -Math.abs(extraction.amount);
    const txType = isOutgoing ? 'INCOME' : 'EXPENSE';

    const txData = {
      transactionId: txId,
      transactionDate: dateStr,
      originalAmount: originalAmount,
      originalCurrency: extraction.currency,
      transactionType: txType,
      merchantOrPayee: extraction.merchant,
      categoryId: extraction.categoryId,
      cashFlowTier: extraction.cashFlowTier,
      accountId: accountId,
      paymentMethod: 'EFT',
      isTaxDeductible: extraction.isTaxDeductible,
      taxInvoiceNumber: extraction.taxInvoiceNumber,
      notes: `${subject.substring(0, 100)} | Attached: ${fileName}`,
      tags: [
        isOutgoing ? 'client_invoice' : 'email_receipt',
        isOutgoing ? 'business_income' : 'expense',
        'gmail_ingest',
        'pdf_attached',
        extraction.isTaxDeductible ? 'tax_deductible' : (isOutgoing ? 'taxable_revenue' : 'standard_expense')
      ],
      receiptName: fileName,
      receiptUrl: receiptUrl,
      metadata: {
        source: 'gmail_parser',
        email_from: fromStr,
        email_subject: subject,
        gcs_bucket: bucketName,
        gcs_object: objectKey,
        gcs_uri: `gs://${bucketName}/${objectKey}`,
        file_size_bytes: attachment.getSize ? attachment.getSize() : 0,
        ingested_at: new Date().toISOString()
      }
    };

    // 6. Ingest into BigQuery warehouse
    let bqResult;
    if (typeof BigQueryClient !== 'undefined' && BigQueryClient.insertTransaction) {
      bqResult = BigQueryClient.insertTransaction(txData);
    } else {
      // Mock / Offline execution support
      bqResult = { success: true, transactionId: txId, mocked: true };
    }

    return {
      success: bqResult.success,
      transactionId: txId,
      data: txData,
      gcsUrl: receiptUrl,
      error: bqResult.error
    };
  }

  /**
   * Extracts Merchant, Amount, Currency, Category, and Tax References
   */
  static extractFinancialData(params) {
    const { from, subject, bodyText, fileName, dateStr } = params;
    const combined = `${subject}\n${from}\n${fileName}\n${bodyText.substring(0, 2000)}`;

    // 1. Merchant Extraction
    let merchant = 'Unknown Merchant';
    // Match sender display name: "Woolworths <no-reply@woolworths.co.za>"
    const fromMatch = from.match(/^"?([^"<@]+)"?\s*<[^>]+>/);
    if (fromMatch && fromMatch[1].trim()) {
      merchant = fromMatch[1].trim();
    } else {
      // Check known retailers/merchants in text
      const known = [
        'Woolworths', 'Checkers', 'Pick n Pay', 'Shoprite', 'Spar', 'Dis-Chem', 'Clicks',
        'Google Cloud', 'Amazon Web Services', 'AWS', 'Apple', 'Microsoft', 'GitHub',
        'Uber', 'Bolt', 'Capitec', 'FNB', 'Econet', 'Eskom', 'ZESA', 'Nandos', 'Vida e Caffe'
      ];
      for (let k = 0; k < known.length; k++) {
        if (new RegExp('\\b' + known[k] + '\\b', 'i').test(combined)) {
          merchant = known[k];
          break;
        }
      }
      if (merchant === 'Unknown Merchant' && subject) {
        merchant = subject.split(/[-:|]/)[0].trim().substring(0, 30);
      }
    }

    // 2. Amount & Currency Extraction
    let amount = 0.0;
    let currency = 'ZAR'; // default reporting base

    // Detect currency
    if (/\b(USD|\$)\b/i.test(combined)) {
      currency = 'USD';
    } else if (/\b(ZiG)\b/i.test(combined)) {
      currency = 'ZiG';
    } else if (/\b(ZAR|R)\b/i.test(combined)) {
      currency = 'ZAR';
    }

    // Amount patterns e.g. "Total: ZAR 1,250.00", "Amount Due: $45.50", "Paid R450.00", "120.00 ZAR"
    const amountRegexes = [
      /(?:total|amount|due|paid|balance|sum)[\s:]*(?:zar|usd|zig|r|\$)?\s*([0-9]{1,3}(?:[, ][0-9]{3})*(?:\.[0-9]{2})|[0-9]+(?:\.[0-9]{2}))/i,
      /(?:zar|usd|zig|r|\$)\s*([0-9]{1,3}(?:[, ][0-9]{3})*(?:\.[0-9]{2})|[0-9]+(?:\.[0-9]{2}))/i,
      /([0-9]{1,3}(?:[, ][0-9]{3})*(?:\.[0-9]{2})|[0-9]+(?:\.[0-9]{2}))\s*(?:zar|usd|zig)/i,
      /([0-9]+(?:\.[0-9]{2}))/
    ];

    for (let r = 0; r < amountRegexes.length; r++) {
      const match = combined.match(amountRegexes[r]);
      if (match && match[1]) {
        const cleaned = match[1].replace(/[, ]/g, '');
        const val = parseFloat(cleaned);
        if (!isNaN(val) && val > 0 && val < 500000) {
          amount = val;
          break;
        }
      }
    }

    // Fallback amount from filename e.g. "Invoice_350.00.pdf"
    if (amount === 0.0) {
      const fileAmtMatch = fileName.match(/([0-9]+(?:\.[0-9]{2}))/);
      if (fileAmtMatch && fileAmtMatch[1]) {
        amount = parseFloat(fileAmtMatch[1]);
      }
    }

    // 3. Tax Invoice Reference
    let taxInvoiceNumber = null;
    const invMatch = combined.match(/\b(INV-[A-Za-z0-9-]+|TAX-[A-Za-z0-9-]+|REC-[A-Za-z0-9-]+|#\d{4,})\b/i);
    if (invMatch) {
      taxInvoiceNumber = invMatch[1].toUpperCase();
    }

    // 4. Detect Outgoing Client Invoices vs Incoming Vendor Bills
    const isOutgoingClientInvoice = /\b(client invoice|invoice to|consulting invoice|services rendered|billed to|our invoice)\b/i.test(combined) ||
      /\b(attached is (our|my) invoice|please find attached (our|my)?\s*invoice)\b/i.test(bodyText) ||
      /^from:\s*me\b/i.test(from);

    // 5. Tax Deductibility Detection
    const isTaxDeductible = !isOutgoingClientInvoice && /\b(tax invoice|vat invoice|tax deductible|business expense|work|consulting|aws|cloud|software|hardware|server|hosting|office)\b/i.test(combined);

    // 6. Category and Cash Flow Tier
    let categoryId = 'CAT_DAILY_GROCERIES';
    let cashFlowTier = 'DAILY_SPENDING';

    if (isOutgoingClientInvoice) {
      categoryId = 'CAT_CLIENT_REVENUE';
      cashFlowTier = 'OPERATIONAL_INCOME';
    } else if (/\b(aws|amazon web services|cloud|google cloud|github|hosting|digitalocean|openai|anthropic|server)\b/i.test(combined)) {
      categoryId = 'CAT_PROD_SOFTWARE_TOOLS';
      cashFlowTier = 'MONTHLY_ALLOCATION';
    } else if (/\b(hardware|laptop|monitor|computer|keyboard|electronics|dell|apple)\b/i.test(combined)) {
      categoryId = 'CAT_PROD_TECH_HARDWARE';
      cashFlowTier = 'MONTHLY_ALLOCATION';
    } else if (/\b(rent|lease|apartment|property)\b/i.test(combined)) {
      categoryId = 'CAT_ALLOC_RENT';
      cashFlowTier = 'MONTHLY_ALLOCATION';
    } else if (/\b(electricity|eskom|zesa|power token|utility)\b/i.test(combined)) {
      categoryId = 'CAT_ALLOC_ELECTRICITY';
      cashFlowTier = 'MONTHLY_ALLOCATION';
    } else if (/\b(uber|bolt|fuel|petrol|diesel|transport|flight)\b/i.test(combined)) {
      categoryId = 'CAT_DAILY_FUEL_TRANS';
      cashFlowTier = 'DAILY_SPENDING';
    } else if (/\b(restaurant|coffee|cafe|dining|nandos|food)\b/i.test(combined)) {
      categoryId = 'CAT_DAILY_DINING';
      cashFlowTier = 'DAILY_SPENDING';
    }

    return {
      merchant,
      amount,
      currency,
      categoryId,
      cashFlowTier,
      isTaxDeductible,
      isOutgoingClientInvoice,
      taxInvoiceNumber
    };
  }

  /**
   * Uploads PDF attachment blob to Google Cloud Storage via REST API.
   * @param {object} attachment GmailAttachment or mock
   * @param {string} objectKey GCS object path
   * @param {string} bucketName Target GCS bucket
   * @returns {object} { success, publicUrl, error }
   */
  static uploadPdfToGcs(attachment, objectKey, bucketName) {
    const publicUrl = `https://storage.googleapis.com/${bucketName}/${objectKey}`;

    // If running in Google Apps Script environment, call GCS JSON API with OAuth token
    if (typeof UrlFetchApp !== 'undefined' && typeof ScriptApp !== 'undefined') {
      try {
        const uploadUrl = `https://storage.googleapis.com/upload/storage/v1/b/${bucketName}/o?uploadType=media&name=${encodeURIComponent(objectKey)}`;
        const token = ScriptApp.getOAuthToken();
        const bytes = attachment.getBytes ? attachment.getBytes() : [];

        const response = UrlFetchApp.fetch(uploadUrl, {
          method: 'post',
          contentType: 'application/pdf',
          headers: {
            Authorization: `Bearer ${token}`
          },
          payload: bytes,
          muteHttpExceptions: true
        });

        const code = response.getResponseCode();
        if (code === 200 || code === 201) {
          console.log(`[GmailParser] Uploaded ${objectKey} to gs://${bucketName}/ successfully.`);
          return { success: true, publicUrl: publicUrl };
        } else {
          console.warn(`[GmailParser] GCS upload HTTP ${code}: ${response.getContentText()}`);
          return { success: false, publicUrl: publicUrl, error: response.getContentText() };
        }
      } catch (err) {
        console.warn(`[GmailParser] GCS upload exception: ${err.message}`);
        return { success: false, publicUrl: publicUrl, error: err.message };
      }
    }

    // Mock / Offline fallback
    return { success: true, publicUrl: publicUrl };
  }

  /**
   * Retrieve configured bucket name from Script Properties or default
   */
  static getGcsBucketName() {
    if (typeof PropertiesService !== 'undefined') {
      const prop = PropertiesService.getScriptProperties().getProperty('GCS_RECEIPT_BUCKET');
      if (prop) return prop;
    }
    return GMAIL_CONFIG.defaultBucketName;
  }

  /**
   * Helper to fetch or create Gmail user label
   */
  static _getOrCreateLabel(name) {
    if (typeof GmailApp === 'undefined') return null;
    let label = GmailApp.getUserLabelByName(name);
    if (!label) {
      label = GmailApp.createLabel(name);
    }
    return label;
  }

  /**
   * Installs an automated time-driven trigger for continuous inbox processing.
   * Runs every 15 minutes.
   */
  static setupGmailTrigger() {
    if (typeof ScriptApp === 'undefined') return;
    this.removeGmailTriggers();
    ScriptApp.newTrigger('scanIncomingReceipts')
      .timeBased()
      .everyMinutes(15)
      .create();
    console.log('[GmailParser] Installed 15-minute time-driven trigger for scanIncomingReceipts.');
  }

  /**
   * Removes existing triggers for scanIncomingReceipts
   */
  static removeGmailTriggers() {
    if (typeof ScriptApp === 'undefined') return;
    const triggers = ScriptApp.getProjectTriggers();
    for (let i = 0; i < triggers.length; i++) {
      if (triggers[i].getHandlerFunction() === 'scanIncomingReceipts') {
        ScriptApp.deleteTrigger(triggers[i]);
      }
    }
  }
}

/**
 * Global entry point callable by Google Apps Script time-driven triggers
 */
function scanIncomingReceipts() {
  return GmailReceiptParser.scanIncomingReceipts();
}

// CommonJS export for Node testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { GmailReceiptParser, scanIncomingReceipts, GMAIL_CONFIG };
}
