class ParsedTransaction {
  final bool success;
  final double? amount;
  final String? currency;
  final String? merchant;
  final String? categoryId;
  final String? categoryName;
  final String transactionType;
  final bool isTaxDeductible;
  final String? invoiceRef;
  final String? notes;
  final String? error;

  const ParsedTransaction({
    required this.success,
    this.amount,
    this.currency,
    this.merchant,
    this.categoryId,
    this.categoryName,
    this.transactionType = 'EXPENSE',
    this.isTaxDeductible = false,
    this.invoiceRef,
    this.notes,
    this.error,
  });

  bool get hasAnyExtractedField =>
      amount != null ||
      merchant != null ||
      categoryId != null ||
      currency != null;
}

class TransactionParser {
  static const List<Map<String, dynamic>> categoryRules = [
    {
      'id': 'CAT_GROCERIES',
      'name': 'Groceries & Household Supplies',
      'isTax': false,
      'keywords': [
        'grocery', 'groceries', 'supermarket', 'food', 'woolworths', 'woolies',
        'checkers', 'pick n pay', 'pnp', 'spar', 'superspar', 'shoprite',
        'ok mart', 'food lovers', 'market', 'meat', 'butcher', 'vegetables',
        'veggies', 'fruit', 'milk', 'bread', 'eggs', 'pantry', 'toiletries',
        'soap', 'detergent', 'household'
      ],
    },
    {
      'id': 'CAT_DINING_COFFEE',
      'name': 'Restaurants, Takeaways & Coffee',
      'isTax': false,
      'keywords': [
        'lunch', 'dinner', 'breakfast', 'brunch', 'coffee', 'cappuccino',
        'latte', 'cafe', 'caffe', 'restaurant', 'takeaway', 'takeaways',
        'fast food', 'burger', 'pizza', 'kfc', 'mcdonalds', 'nandos',
        'steers', 'wimpy', 'vida', 'starbucks', 'beer', 'drinks', 'bar',
        'cocktail', 'wine', 'snack', 'pastry', 'bakery'
      ],
    },
    {
      'id': 'CAT_TECH_HARDWARE',
      'name': 'Productivity Tech & Work Hardware',
      'isTax': true,
      'keywords': [
        'laptop', 'macbook', 'dell', 'thinkpad', 'lenovo', 'monitor',
        'screen', 'display', 'keyboard', 'mouse', 'trackpad', 'dock',
        'docking station', 'usb-c hub', 'webcam', 'headset', 'headphones',
        'work desk', 'standing desk', 'ergonomic chair', 'desk chair',
        'ssd', 'hard drive', 'hardware', 'work computer', 'office desk'
      ],
    },
    {
      'id': 'CAT_SOFTWARE_SAAS',
      'name': 'Business Software & Cloud Subscriptions',
      'isTax': true,
      'keywords': [
        'software', 'subscription', 'saas', 'aws', 'gcp', 'cloud', 'google cloud',
        'azure', 'github', 'jetbrains', 'cursor', 'openai', 'chatgpt',
        'anthropic', 'slack', 'notion', 'figma', 'vercel', 'domain',
        'godaddy', 'namecheap', 'docker', 'apple developer'
      ],
    },
    {
      'id': 'CAT_FIBRE_INTERNET',
      'name': 'High-Speed Home Fibre',
      'isTax': true,
      'keywords': [
        'fibre', 'fiber', 'home internet', 'broadband', 'wifi', 'openserve',
        'vumatel', 'frogfoot', 'webafrica', 'afrihost', 'cool ideas',
        'liquid telecom', 'zol', 'fibroniks'
      ],
    },
    {
      'id': 'CAT_RENT',
      'name': 'Residential Rent & Levies',
      'isTax': false,
      'keywords': [
        'rent', 'rental', 'lease', 'apartment', 'flat', 'landlord',
        'body corporate', 'levy', 'levies', 'estate levy', 'mortgage', 'bond'
      ],
    },
    {
      'id': 'CAT_TAX_STATUTORY',
      'name': 'Provisional & Statutory Tax Payments',
      'isTax': true,
      'keywords': [
        'sars', 'tax', 'provisional tax', 'provisional', 'irp6', 'vat',
        'statutory', 'tax return', 'revenue service', 'zimra'
      ],
    },
  ];

  /// Parses natural language string into a structured transaction.
  /// Example: "Spent 120 ZAR on groceries at Woolworths today"
  /// Example: "Bought 4500 ZAR standing desk for work invoice INV-WORK-771"
  static ParsedTransaction parse(String rawInput) {
    if (rawInput.trim().isEmpty) {
      return const ParsedTransaction(success: false, error: 'Empty input');
    }

    final input = rawInput.trim();
    final lower = input.toLowerCase();

    // 1. Transaction Type Detection
    final isIncome = RegExp(r'\b(salary|received|got paid|income|retainer|dividend|bonus)\b', caseSensitive: false).hasMatch(input);
    final txType = isIncome ? 'INCOME' : 'EXPENSE';

    // 2. Extract Currency & Amount
    // Matches: 120 ZAR, 120.50 USD, R120, R 120, $45.50, 45.50$, 150 ZiG
    double? extractedAmount;
    String? extractedCurrency;

    // A. Pattern: Amount followed by currency (e.g., 120 ZAR, 45.50 USD, 300 ZiG)
    final suffixMatch = RegExp(r'(\d+(?:[.,]\d{1,2})?)\s*(ZAR|USD|ZiG|rand|rands|dollars?|zig)\b', caseSensitive: false).firstMatch(input);
    // B. Pattern: Currency symbol followed by amount (e.g., R120, R 120, $45.50)
    final prefixMatch = RegExp(r'(?:([R$]|ZAR|USD|ZiG))\s*(\d+(?:[.,]\d{1,2})?)', caseSensitive: false).firstMatch(input);
    // C. Pattern: Standalone decimal/number
    final standaloneNumMatch = RegExp(r'\b(\d+(?:[.,]\d{1,2})?)\b').firstMatch(input);

    if (suffixMatch != null) {
      final numStr = suffixMatch.group(1)!.replaceAll(',', '.');
      extractedAmount = double.tryParse(numStr);
      final rawCurr = suffixMatch.group(2)!.toUpperCase();
      if (rawCurr.contains('USD') || rawCurr.contains('DOLLAR')) {
        extractedCurrency = 'USD';
      } else if (rawCurr.contains('ZIG')) {
        extractedCurrency = 'ZiG';
      } else {
        extractedCurrency = 'ZAR';
      }
    } else if (prefixMatch != null) {
      final numStr = prefixMatch.group(2)!.replaceAll(',', '.');
      extractedAmount = double.tryParse(numStr);
      final sym = prefixMatch.group(1)!.toUpperCase();
      if (sym == r'$' || sym == 'USD') {
        extractedCurrency = 'USD';
      } else if (sym == 'ZIG') {
        extractedCurrency = 'ZiG';
      } else {
        extractedCurrency = 'ZAR';
      }
    } else if (standaloneNumMatch != null) {
      final numStr = standaloneNumMatch.group(1)!.replaceAll(',', '.');
      extractedAmount = double.tryParse(numStr);
      if (lower.contains('usd') || lower.contains(r'$')) {
        extractedCurrency = 'USD';
      } else if (lower.contains('zig')) {
        extractedCurrency = 'ZiG';
      } else {
        extractedCurrency = 'ZAR';
      }
    }

    // 3. Extract Invoice Reference Number (e.g. INV-WORK-771, TAX-2026, #4829)
    String? invoiceRef;
    final invMatch = RegExp(r'\b(INV-[A-Z0-9-]+|TAX-[A-Z0-9-]+|#\d+)\b', caseSensitive: false).firstMatch(input);
    if (invMatch != null) {
      invoiceRef = invMatch.group(1);
    }

    // 4. Extract Merchant / Payee
    String? extractedMerchant;
    // Look for "at [Merchant]" or "from [Merchant]"
    final atMatch = RegExp(r'\b(?:at|from)\s+([A-Za-z0-9&.\s\x27-]+?)(?:\s+(?:for|on|with|today|yesterday|invoice)|$)', caseSensitive: false).firstMatch(input);
    if (atMatch != null && atMatch.group(1) != null && atMatch.group(1)!.trim().isNotEmpty) {
      extractedMerchant = _cleanMerchantName(atMatch.group(1)!.trim());
    }

    // Common named merchants if "at" pattern didn't catch it
    if (extractedMerchant == null || extractedMerchant.isEmpty) {
      final knownMerchants = [
        'Woolworths', 'Checkers', 'Pick n Pay', 'Spar', 'Nandos', 'KFC',
        'McDonalds', 'Steers', 'Wimpy', 'Starbucks', 'Afrihost', 'Telkom',
        'Vodacom', 'MTN', 'EcoCash', 'Discovery', 'EasyEquities', 'Apple',
        'Uber', 'Bolt', 'Shell', 'Engen', 'Sasol', 'BP', 'SARS', 'Amazon',
      ];
      for (final m in knownMerchants) {
        if (RegExp('\\b$m\\b', caseSensitive: false).hasMatch(input)) {
          extractedMerchant = m;
          break;
        }
      }
    }

    // Fallback: extract item/payee from cleaned remainder (matching Slack Parser.js logic)
    if (extractedMerchant == null || extractedMerchant.isEmpty) {
      var remainder = input;
      if (suffixMatch != null) remainder = remainder.replaceAll(suffixMatch.group(0)!, ' ');
      if (prefixMatch != null) remainder = remainder.replaceAll(prefixMatch.group(0)!, ' ');
      if (invoiceRef != null) remainder = remainder.replaceAll(invoiceRef, ' ');

      remainder = remainder
          .replaceAll(RegExp(r'\b(spent|paid|bought|purchase|purchased|received|got|on|for|at|via|using|from|with|in|today|yesterday|invoice|work|business)\b', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (remainder.isNotEmpty) {
        extractedMerchant = _cleanMerchantName(remainder);
      }
    }

    // 5. Category Detection
    String? categoryId;
    String? categoryName;
    bool isTax = false;

    int bestScore = 0;
    for (final rule in categoryRules) {
      final keywords = rule['keywords'] as List<String>;
      int score = 0;
      for (final kw in keywords) {
        if (lower.contains(kw)) {
          score += kw.length; // weight longer keyword matches higher
        }
      }
      if (score > bestScore) {
        bestScore = score;
        categoryId = rule['id'] as String;
        categoryName = rule['name'] as String;
        isTax = rule['isTax'] as bool;
      }
    }

    // 6. Tax Deductibility Detection
    if (!isTax) {
      final taxKeywords = ['work', 'business', 'deductible', 'sars', 'invoice', 'client', 'consulting'];
      if (taxKeywords.any((k) => lower.contains(k))) {
        isTax = true;
      }
    }

    // Format notes
    final notes = invoiceRef != null
        ? 'Invoice: $invoiceRef • Extracted via natural language'
        : 'Auto-extracted from: "$input"';

    return ParsedTransaction(
      success: extractedAmount != null,
      amount: extractedAmount,
      currency: extractedCurrency ?? 'ZAR',
      merchant: extractedMerchant,
      categoryId: categoryId,
      categoryName: categoryName,
      transactionType: txType,
      isTaxDeductible: isTax,
      invoiceRef: invoiceRef,
      notes: notes,
    );
  }

  /// Parses receipt filename and extracted OCR text
  static ParsedTransaction parseReceipt({
    required String fileName,
    String? fileContent,
    int? fileSize,
  }) {
    final combined = '$fileName ${fileContent ?? ''}';
    final parsedNlp = parse(combined);

    // If filename has amounts like "Woolworths_ZAR_345.50.pdf"
    double? amount = parsedNlp.amount;
    String? currency = parsedNlp.currency;
    String? merchant = parsedNlp.merchant;
    String? catId = parsedNlp.categoryId;
    String? catName = parsedNlp.categoryName;
    bool isTax = parsedNlp.isTaxDeductible;

    // Fallback amount check on filename
    if (amount == null) {
      final numMatch = RegExp(r'(\d+(?:[._]\d{1,2})?)').firstMatch(fileName);
      if (numMatch != null) {
        amount = double.tryParse(numMatch.group(1)!.replaceAll('_', '.'));
      }
    }

    // Default merchant from filename if not identified
    if (merchant == null || merchant.isEmpty) {
      final cleanName = fileName
          .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
          .replaceAll(RegExp(r'[_-]'), ' ')
          .trim();
      final words = cleanName.split(' ');
      if (words.isNotEmpty) {
        merchant = words.first;
      }
    }

    // Default category to Groceries or Tech if unknown
    catId ??= 'CAT_GROCERIES';
    catName ??= 'Groceries & Household Supplies';

    final notes = 'Scanned from receipt: $fileName${fileSize != null ? ' (${(fileSize / 1024).toStringAsFixed(1)} KB)' : ''}';

    return ParsedTransaction(
      success: amount != null || merchant != null,
      amount: amount ?? 0.0,
      currency: currency ?? 'ZAR',
      merchant: merchant ?? 'Scanned Merchant',
      categoryId: catId,
      categoryName: catName,
      transactionType: 'EXPENSE',
      isTaxDeductible: isTax,
      notes: notes,
    );
  }

  static String _cleanMerchantName(String raw) {
    var s = raw.replaceAll(RegExp(r'^(the|a|an)\s+', caseSensitive: false), '').trim();
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
