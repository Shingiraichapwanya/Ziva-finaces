/**
 * Parser.js - Natural Language Financial Transaction Parser
 * Compatible with Google Apps Script (V8 runtime) and Node.js.
 */

const CATEGORY_DEFINITIONS = [
  {
    id: 'CAT_DAILY_DINING',
    tier: 'DAILY_SPENDING',
    name: 'Restaurants, Takeaways & Coffee',
    keywords: [
      'lunch', 'dinner', 'breakfast', 'brunch', 'coffee', 'cappuccino', 'latte',
      'cafe', 'caffe', 'restaurant', 'takeaway', 'takeaways', 'fast food',
      'burger', 'pizza', 'kfc', 'mcdonalds', 'nandos', 'steers', 'wimpy',
      'vida', 'vida e caffe', 'starbucks', 'bakers inn', 'chicken inn', 'pizza inn',
      'beer', 'drinks', 'bar', 'cocktail', 'wine', 'snack', 'pastry', 'bakery'
    ]
  },
  {
    id: 'CAT_DAILY_GROCERIES',
    tier: 'DAILY_SPENDING',
    name: 'Groceries & Household Supplies',
    keywords: [
      'grocery', 'groceries', 'supermarket', 'food', 'woolworths', 'checkers',
      'pick n pay', 'pnp', 'spar', 'superspar', 'shoprite', 'ok mart', 'food lovers',
      'market', 'meat', 'butchery', 'butcher', 'vegetables', 'veggies', 'fruit',
      'milk', 'bread', 'eggs', 'pantry', 'toiletries', 'supplies', 'soap', 'detergent'
    ]
  },
  {
    id: 'CAT_DAILY_FUEL_TRANS',
    tier: 'DAILY_SPENDING',
    name: 'Fuel, Uber & Commute',
    keywords: [
      'fuel', 'petrol', 'diesel', 'gas', 'uber', 'bolt', 'taxi', 'commute',
      'transport', 'parking', 'toll', 'e-toll', 'shell', 'engen', 'sasol',
      'bp', 'totalenergies', 'car wash', 'bus', 'train', 'gautrain'
    ]
  },
  {
    id: 'CAT_DAILY_AIRTIME',
    tier: 'DAILY_SPENDING',
    name: 'Mobile Airtime & Bundles',
    keywords: [
      'airtime', 'data', 'bundle', 'bundles', 'mobile', 'econet', 'netone',
      'telecel', 'vodacom', 'mtn', 'cell c', 'telkom mobile', 'recharge',
      'smartbiz', 'whatsapp bundle'
    ]
  },
  {
    id: 'CAT_ALLOC_ELECTRICITY',
    tier: 'MONTHLY_ALLOCATION',
    name: 'Pre-paid Power & Utility Tokens',
    keywords: [
      'electricity', 'power', 'zesa', 'zetdc', 'eskom', 'power token', 'token',
      'kwh', 'prepaid power', 'utility token'
    ]
  },
  {
    id: 'CAT_ALLOC_RENT',
    tier: 'MONTHLY_ALLOCATION',
    name: 'Residential Rent & Levies',
    keywords: [
      'rent', 'rental', 'lease', 'apartment', 'flat', 'landlord', 'body corporate',
      'levy', 'levies', 'estate levy', 'mortgage', 'bond'
    ]
  },
  {
    id: 'CAT_ALLOC_MEDICAL',
    tier: 'MONTHLY_ALLOCATION',
    name: 'Medical Aid Scheme',
    keywords: [
      'medical', 'doctor', 'physio', 'dentist', 'pharmacy', 'dischem', 'clicks',
      'medication', 'medicine', 'prescription', 'discovery health', 'cimas',
      'medical aid', 'hospital'
    ]
  },
  {
    id: 'CAT_ALLOC_INTERNET',
    tier: 'MONTHLY_ALLOCATION',
    name: 'High-Speed Home Fibre',
    isTaxDeductible: true,
    taxLineItem: 'HOME_OFFICE_DEDUCTION',
    keywords: [
      'fibre', 'fiber', 'home internet', 'broadband', 'openserve', 'vumatel',
      'frogfoot', 'webafrica', 'afrihost', 'cool ideas', 'liquid telecom',
      'zol', 'fibroniks'
    ]
  },
  {
    id: 'CAT_PROD_TECH_HARDWARE',
    tier: 'DAILY_SPENDING',
    name: 'Productivity Tech & Work Hardware',
    isTaxDeductible: true,
    taxLineItem: 'PRODUCTIVITY_HARDWARE',
    keywords: [
      'laptop', 'macbook', 'dell', 'thinkpad', 'lenovo', 'hp laptop', 'monitor',
      'screen', 'display', 'keyboard', 'mouse', 'trackpad', 'dock', 'docking station',
      'usb-c hub', 'webcam', 'headset', 'headphones', 'ups', 'inverter', 'work desk',
      'standing desk', 'ergonomic chair', 'desk chair', 'ram', 'ssd', 'hard drive',
      'workstation', 'hardware', 'gadget', 'charger'
    ]
  },
  {
    id: 'CAT_PROD_SOFTWARE_TOOLS',
    tier: 'MONTHLY_ALLOCATION',
    name: 'Business Software, Cloud & AI Subscriptions',
    isTaxDeductible: true,
    taxLineItem: 'BUSINESS_SOFTWARE',
    keywords: [
      'chatgpt', 'claude', 'anthropic', 'openai', 'github', 'copilot', 'aws',
      'gcp', 'google cloud', 'azure', 'jetbrains', 'figma', 'cursor', 'notion',
      'linear', 'slack subscription', 'zoom', 'software license', 'hosting',
      'domain', 'saas'
    ]
  },
  {
    id: 'CAT_PROD_PROFESSIONAL_SERVICES',
    tier: 'MONTHLY_ALLOCATION',
    name: 'Professional Services & Compliance',
    isTaxDeductible: true,
    taxLineItem: 'PROFESSIONAL_SERVICES',
    keywords: [
      'accountant', 'accounting', 'bookkeeper', 'bookkeeping', 'tax practitioner',
      'tax return prep', 'tax advice', 'legal fees', 'lawyer', 'attorney',
      'cipc', 'company registration', 'compliance filing'
    ]
  },
  {
    id: 'CAT_TAX_STATUTORY_PROVISIONAL',
    tier: 'MONTHLY_ALLOCATION',
    name: 'Provisional & Statutory Tax Payments',
    isTaxDeductible: false,
    taxLineItem: 'STATUTORY_TAX_PAYMENT',
    keywords: [
      'sars', 'zimra', 'provisional tax', 'tax payment', 'taxes', 'paye',
      'qpd', 'corporate tax', 'vat payment', 'irp6'
    ]
  },
  {
    id: 'CAT_ALLOC_INSURANCE',
    tier: 'MONTHLY_ALLOCATION',
    name: 'Short-Term Vehicle & Asset Cover',
    keywords: [
      'insurance', 'outsurance', 'santam', 'old mutual insurance', 'car insurance',
      'vehicle cover', 'household insurance', 'policy premium'
    ]
  },
  {
    id: 'CAT_ALLOC_SUBSCRIPTIONS',
    tier: 'MONTHLY_ALLOCATION',
    name: 'Digital Subscriptions',
    keywords: [
      'netflix', 'spotify', 'youtube', 'icloud', 'apple music', 'amazon prime',
      'disney', 'subscription', 'streaming'
    ]
  },
  {
    id: 'CAT_VAULT_GLOBAL_ETF',
    tier: 'LONG_TERM_VAULT',
    name: 'Offshore S&P 500 Index Equities',
    keywords: [
      'etf', 'shares', 'stocks', 'easyequities', 's&p', 's&p500', 'top40',
      'unit trust', 'investments', 'offshore fund', 'equity', 'brokerage'
    ]
  },
  {
    id: 'CAT_VAULT_EMERGENCY',
    tier: 'LONG_TERM_VAULT',
    name: 'Liquid Emergency Reserve Fund',
    keywords: [
      'emergency fund', '32-day', 'notice deposit', 'vault deposit', 'savings vault',
      'reserve fund'
    ]
  },
  {
    id: 'CAT_INC_SALARY',
    tier: 'MONTHLY_ALLOCATION',
    name: 'Consulting & Employment Income',
    keywords: [
      'salary', 'retainer', 'client fee', 'consulting', 'invoice paid',
      'earnings', 'paycheck', 'payroll', 'consulting fee'
    ]
  },
  {
    id: 'CAT_INC_DIVIDENDS',
    tier: 'LONG_TERM_VAULT',
    name: 'Investment Dividends',
    keywords: [
      'dividend', 'dividends', 'distribution', 'yield payout'
    ]
  },
  {
    id: 'CAT_DAILY_INCIDENTAL',
    tier: 'DAILY_SPENDING',
    name: 'Micro-Cash & Incidentals',
    keywords: ['tip', 'car guard', 'parking tip', 'incidental', 'petty cash', 'minor']
  }
];

const ACCOUNT_ROUTING = {
  // South Africa (ZAR)
  ZAR: {
    DAILY_SPENDING: {
      id: 'ACC_ZA_CAPITEC_DAILY',
      name: 'Capitec Primary Cheque',
      paymentMethod: 'DEBIT_CARD'
    },
    MONTHLY_ALLOCATION: {
      id: 'ACC_ZA_FNB_MONTHLY',
      name: 'FNB Monthly Bills Fusion',
      paymentMethod: 'DIRECT_DEBIT'
    },
    LONG_TERM_VAULT: {
      id: 'ACC_ZA_EE_EQUITIES_VAULT',
      name: 'EasyEquities S&P500 & Top40 TFSA',
      paymentMethod: 'EFT'
    }
  },
  // Zimbabwe (USD)
  USD: {
    DAILY_SPENDING: {
      id: 'ACC_ZW_ECOCASH_USD',
      name: 'EcoCash USD Wallet',
      paymentMethod: 'MOBILE_MONEY_ECOCASH'
    },
    MONTHLY_ALLOCATION: {
      id: 'ACC_ZW_STANBIC_NOSTRO',
      name: 'Stanbic Nostro FCA Bills',
      paymentMethod: 'DEBIT_CARD'
    },
    LONG_TERM_VAULT: {
      id: 'ACC_ZW_OM_UNITTRUST_VAULT',
      name: 'Old Mutual USD Balanced Unit Trust',
      paymentMethod: 'EFT'
    }
  },
  // Zimbabwe Gold (ZiG)
  ZiG: {
    DAILY_SPENDING: {
      id: 'ACC_ZW_ECOCASH_ZIG',
      name: 'EcoCash ZiG Wallet',
      paymentMethod: 'MOBILE_MONEY_ECOCASH'
    },
    MONTHLY_ALLOCATION: {
      id: 'ACC_ZW_ECOCASH_ZIG',
      name: 'EcoCash ZiG Wallet',
      paymentMethod: 'MOBILE_MONEY_ECOCASH'
    },
    LONG_TERM_VAULT: {
      id: 'ACC_ZW_OM_UNITTRUST_VAULT',
      name: 'Old Mutual USD Balanced Unit Trust',
      paymentMethod: 'EFT'
    }
  }
};

/**
 * Natural language transaction parser.
 */
class TransactionParser {
  /**
   * Parse a natural language input string into a structured transaction draft.
   * @param {string} rawInput 
   * @returns {object} Parsed transaction object or error
   */
  static parse(rawInput) {
    if (!rawInput || typeof rawInput !== 'string' || !rawInput.trim()) {
      return { success: false, error: 'Empty transaction input string.' };
    }

    const cleanInput = rawInput.trim();

    // 1. Detect transaction direction (Income vs Expense)
    const expenseTriggers = ['spent', 'bought', 'paid', 'purchase', 'purchased', 'ordered'];
    const incomeTriggers = ['salary', 'received', 'got paid', 'income', 'retainer', 'freelance', 'dividend', 'bonus', 'paycheck', 'payroll'];
    
    const hasExpenseTrigger = expenseTriggers.some(kw => new RegExp(`\\b${kw}\\b`, 'i').test(cleanInput));
    const hasIncomeTrigger = incomeTriggers.some(kw => new RegExp(`\\b${kw}\\b`, 'i').test(cleanInput));

    let isIncome = false;
    if (hasIncomeTrigger && !hasExpenseTrigger) {
      isIncome = true;
    } else if (hasIncomeTrigger && hasExpenseTrigger) {
      if (/\b(?:salary|received|got paid|dividend)\b/i.test(cleanInput)) {
        isIncome = true;
      }
    }
    const transactionType = isIncome ? 'INCOME' : 'EXPENSE';

    // 2. Extract Currency & Amount
    // Regex matches formats: R50, R 50, 50 ZAR, 50zar, $12.50, 12.50 USD, 245 ZiG, 245zig, USD 50
    const currencyAmountRegex = /(?:([R$]|ZAR|USD|ZiG)\s*)?(\d+(?:[.,]\d{1,2})?)(?:\s*(ZAR|USD|ZiG))?/i;
    const match = cleanInput.match(currencyAmountRegex);

    if (!match || !match[2]) {
      return {
        success: false,
        error: `Could not determine transaction amount from input: "${rawInput}". Example: "Spent 50 ZAR on lunch"`
      };
    }

    const rawNumericStr = match[2].replace(',', '.');
    const parsedAmount = parseFloat(rawNumericStr);

    if (isNaN(parsedAmount) || parsedAmount <= 0) {
      return { success: false, error: `Invalid numeric amount parsed: "${match[2]}"` };
    }

    // Determine currency symbol or code
    let currency = 'ZAR'; // Default base currency
    const prefixCur = match[1] ? match[1].toUpperCase() : null;
    const suffixCur = match[3] ? match[3].toUpperCase() : null;

    if (prefixCur === 'R' || prefixCur === 'ZAR' || suffixCur === 'ZAR') {
      currency = 'ZAR';
    } else if (prefixCur === '$' || prefixCur === 'USD' || suffixCur === 'USD') {
      currency = 'USD';
    } else if (prefixCur === 'ZIG' || suffixCur === 'ZIG') {
      currency = 'ZiG';
    } else if (cleanInput.toUpperCase().includes('ZIG')) {
      currency = 'ZiG';
    } else if (cleanInput.toUpperCase().includes('USD') || cleanInput.includes('$')) {
      currency = 'USD';
    } else if (cleanInput.toUpperCase().includes('ZAR') || cleanInput.includes('R')) {
      currency = 'ZAR';
    }

    // Amount signed: negative for expense, positive for income
    const signedAmount = isIncome ? parsedAmount : -parsedAmount;

    // 3. Extract Merchant / Payee & Note
    // Strip amount, currency, and common stop words from the input
    let remainder = cleanInput
      .replace(match[0], ' ')
      .replace(/\b(spent|paid|bought|received|got|on|for|at|via|using|from|with|in)\b/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    // Specific merchant pattern: "at [Merchant]" or "from [Merchant]"
    let merchantOrPayee = 'Direct Transaction';
    const atMatch = cleanInput.match(/(?:at|from)\s+([A-Za-z0-9\s'&.-]+?)(?:\s+(?:for|on|with|via)|$)/i);
    if (atMatch && atMatch[1] && atMatch[1].trim()) {
      merchantOrPayee = atMatch[1].trim();
    } else if (remainder.length > 0) {
      // Capitalize first letter of remainder as payee/merchant
      merchantOrPayee = remainder.charAt(0).toUpperCase() + remainder.slice(1);
    }

    // 4. Map Category based on keywords
    let matchedCategory = null;
    const lowerInput = cleanInput.toLowerCase();

    for (const catDef of CATEGORY_DEFINITIONS) {
      for (const kw of catDef.keywords) {
        // Regex word boundary match
        const regex = new RegExp(`\\b${kw.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')}\\b`, 'i');
        if (regex.test(lowerInput)) {
          matchedCategory = catDef;
          break;
        }
      }
      if (matchedCategory) break;
    }

    // Default fallback if no keyword matches
    if (!matchedCategory) {
      if (isIncome) {
        matchedCategory = CATEGORY_DEFINITIONS.find(c => c.id === 'CAT_INC_SALARY');
      } else {
        matchedCategory = CATEGORY_DEFINITIONS.find(c => c.id === 'CAT_DAILY_INCIDENTAL');
      }
    }

    // 5. Deduce Account & Cash Flow Tier
    const tier = matchedCategory.tier;
    const currencyRouting = ACCOUNT_ROUTING[currency] || ACCOUNT_ROUTING.ZAR;
    const accountInfo = currencyRouting[tier] || currencyRouting.DAILY_SPENDING;

    // Refine payment method based on keywords in input
    let paymentMethod = accountInfo.paymentMethod;
    if (/ecocash/i.test(cleanInput)) paymentMethod = 'MOBILE_MONEY_ECOCASH';
    else if (/innbucks/i.test(cleanInput)) paymentMethod = 'MOBILE_MONEY_INNBUCKS';
    else if (/card|swipe/i.test(cleanInput)) paymentMethod = 'DEBIT_CARD';
    else if (/cash/i.test(cleanInput)) paymentMethod = 'CASH';
    else if (/eft|transfer/i.test(cleanInput)) paymentMethod = 'EFT';

    // 6. Deduce Tax Deductibility & Invoice / Receipt Reference
    const taxDeductibleKeywords = /(?:tax[- ]?deductible|tax offset|business (?:expense|purchase)|for work|work expense|home office|biz expense)/i;
    const explicitlyTaxDeductible = taxDeductibleKeywords.test(cleanInput);
    const isTaxDeductible = explicitlyTaxDeductible || Boolean(matchedCategory.isTaxDeductible);
    const taxDeductibleAmount = isTaxDeductible ? parsedAmount : 0.0;

    // Extract invoice or reference number (e.g. "invoice INV-102", "ref SARS-2026-Q1", "receipt #8812")
    let taxInvoiceNumber = null;
    const invoiceMatch = cleanInput.match(/(?:inv(?:oice)?|ref(?:erence)?|receipt)[\s:#-]+([A-Za-z0-9_-]+)/i);
    if (invoiceMatch && invoiceMatch[1]) {
      taxInvoiceNumber = invoiceMatch[1];
    }

    const tags = [tier.toLowerCase().replace(/_/g, '-'), currency.toLowerCase()];
    if (isTaxDeductible) tags.push('tax-deductible');
    if (matchedCategory.taxLineItem === 'STATUTORY_TAX_PAYMENT') tags.push('statutory-tax');

    return {
      success: true,
      data: {
        rawInput: cleanInput,
        transactionType,
        originalAmount: signedAmount,
        absoluteAmount: parsedAmount,
        originalCurrency: currency,
        categoryId: matchedCategory.id,
        categoryName: matchedCategory.name,
        taxLineItem: matchedCategory.taxLineItem || 'NON_DEDUCTIBLE',
        cashFlowTier: tier,
        accountId: accountInfo.id,
        accountName: accountInfo.name,
        merchantOrPayee: merchantOrPayee || matchedCategory.name,
        paymentMethod,
        isTaxDeductible,
        taxDeductibleAmount,
        taxInvoiceNumber,
        notes: cleanInput,
        tags
      }
    };
  }
}

const Parser = TransactionParser;

// Support CommonJS export for Node testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    TransactionParser,
    Parser,
    CATEGORY_DEFINITIONS,
    ACCOUNT_ROUTING
  };
}

