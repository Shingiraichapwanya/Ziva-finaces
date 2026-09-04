import React, { useState } from 'react';
import { Transaction, MasterCurrency, ExchangeRates, CurrencyCode } from '../../types/finance';
import { convertCurrency } from '../../services/currency';
import { Search, Plus, Filter, ArrowUpRight, ArrowDownLeft, FileText, CheckCircle } from 'lucide-react';

interface TransactionsViewProps {
  transactions: Transaction[];
  masterCurrency: MasterCurrency;
  rates: ExchangeRates;
  onAddTransaction: (tx: Transaction) => void;
}

export const TransactionsView: React.FC<TransactionsViewProps> = ({
  transactions,
  masterCurrency,
  rates,
  onAddTransaction
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCurrency, setSelectedCurrency] = useState<CurrencyCode | 'ALL'>('ALL');
  const [onlyTaxDeductible, setOnlyTaxDeductible] = useState(false);
  const [showAddForm, setShowAddForm] = useState(false);

  // Quick Ingest State
  const [nlpInput, setNlpInput] = useState('');

  const filteredTransactions = transactions.filter((tx) => {
    const matchesSearch =
      tx.merchantOrPayee.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (tx.categoryName && tx.categoryName.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (tx.taxInvoiceNumber && tx.taxInvoiceNumber.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (tx.notes && tx.notes.toLowerCase().includes(searchTerm.toLowerCase()));

    const matchesCurrency = selectedCurrency === 'ALL' || tx.originalCurrency === selectedCurrency;
    const matchesTax = !onlyTaxDeductible || tx.isTaxDeductible;

    return matchesSearch && matchesCurrency && matchesTax;
  });

  const handleQuickSpend = (e: React.FormEvent) => {
    e.preventDefault();
    if (!nlpInput.trim()) return;

    // Simple client-side parser fallback matching Parser.js rules
    const text = nlpInput.trim();
    const isWork = /work|hardware|laptop|monitor|screen|ai|claude|chatgpt/i.test(text);
    const invoiceMatch = text.match(/(?:inv|ref|receipt)[\s:#-]+([A-Za-z0-9_-]+)/i);

    let amount = 100;
    const numMatch = text.match(/(\d+(?:\.\d{1,2})?)/);
    if (numMatch) amount = parseFloat(numMatch[1]);

    let currency: CurrencyCode = 'ZAR';
    if (/usd|\$/i.test(text)) currency = 'USD';
    else if (/zig/i.test(text)) currency = 'ZiG';

    const newTx: Transaction = {
      transactionId: `TX_UI_${Date.now().toString().slice(-6)}`,
      transactionTimestamp: new Date().toISOString(),
      transactionDate: new Date().toISOString().split('T')[0],
      localTimezone: 'Africa/Johannesburg',
      accountId: currency === 'USD' ? 'ACC_ZW_ECOCASH_USD' : currency === 'ZiG' ? 'ACC_ZW_ECOCASH_ZIG' : 'ACC_ZA_CAPITEC_DAILY',
      cashFlowTier: 'DAILY_SPENDING',
      categoryId: isWork ? 'CAT_PROD_TECH_HARDWARE' : 'CAT_DAILY_DINING',
      categoryName: isWork ? 'Productivity Tech & Work Hardware' : 'Restaurants, Takeaways & Coffee',
      transactionType: 'EXPENSE',
      originalAmount: -amount,
      originalCurrency: currency,
      reportingAmountUsd: currency === 'USD' ? -amount : -amount * rates.ZAR_TO_USD,
      reportingAmountZar: currency === 'ZAR' ? -amount : -amount * rates.USD_TO_ZAR,
      appliedExchangeRateUsd: rates.ZAR_TO_USD,
      appliedExchangeRateZar: 1.0,
      rateTypeApplied: 'OFFICIAL_INTERBANK',
      merchantOrPayee: text.replace(/spent|paid|bought|for|on/gi, '').trim() || 'Direct Expense',
      paymentMethod: 'DEBIT_CARD',
      isTaxDeductible: isWork,
      taxDeductibleAmountZar: isWork ? amount : undefined,
      taxInvoiceNumber: invoiceMatch ? invoiceMatch[1] : undefined,
      tags: ['ui-ingest', currency.toLowerCase(), isWork ? 'tax-deductible' : 'personal'],
      isSynced: true
    };

    onAddTransaction(newTx);
    setNlpInput('');
    setShowAddForm(false);
  };

  return (
    <div className="transactions-view animate-fade-in">
      <div className="page-header">
        <div>
          <h2>Financial Transaction Ledger</h2>
          <p className="page-subtitle">
            Unified multi-account double-entry ledger partitioned by date in BigQuery.
          </p>
        </div>
        <button
          type="button"
          className="btn btn-primary"
          onClick={() => setShowAddForm(!showAddForm)}
        >
          <Plus size={16} />
          <span>Log Spend</span>
        </button>
      </div>

      {/* Quick Ingestion Form */}
      {showAddForm && (
        <form onSubmit={handleQuickSpend} className="glass-panel quick-spend-form">
          <div className="form-header">
            <h4>Quick Spend Input (Natural Language Parser)</h4>
            <span className="badge badge-gold">Compatible with /spend Slack Bot</span>
          </div>
          <div className="input-group">
            <input
              type="text"
              className="nlp-input mono"
              placeholder="e.g. Spent 4500 ZAR standing desk for work invoice INV-WORK-771"
              value={nlpInput}
              onChange={(e) => setNlpInput(e.target.value)}
              autoFocus
            />
            <button type="submit" className="btn btn-primary">
              Ingest to Warehouse
            </button>
          </div>
          <div className="form-hint">
            💡 Type natural language phrases with currencies (<code>ZAR</code>, <code>USD</code>, <code>ZiG</code>) and invoice references to automatically trigger tax deductions.
          </div>
        </form>
      )}

      {/* Filter Bar */}
      <div className="ledger-controls glass-panel">
        <div className="search-box">
          <Search size={16} className="text-muted" />
          <input
            type="text"
            placeholder="Search merchant, category, or invoice ref..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>

        <div className="controls-right">
          {/* Currency Pill Filter */}
          <div className="currency-filter-pills">
            {(['ALL', 'ZAR', 'USD', 'ZiG'] as (CurrencyCode | 'ALL')[]).map((cur) => (
              <button
                key={cur}
                type="button"
                className={`filter-pill-sm ${selectedCurrency === cur ? 'active' : ''}`}
                onClick={() => setSelectedCurrency(cur)}
              >
                {cur}
              </button>
            ))}
          </div>

          {/* Tax Deductible Toggle */}
          <label className="tax-toggle-label">
            <input
              type="checkbox"
              checked={onlyTaxDeductible}
              onChange={(e) => setOnlyTaxDeductible(e.target.checked)}
            />
            <span>💼 Tax Deductible Only</span>
          </label>
        </div>
      </div>

      {/* Table */}
      <div className="glass-panel ledger-table-wrapper">
        <table className="ledger-table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Payee / Merchant</th>
              <th>Category & Tier</th>
              <th>Tax Compliance</th>
              <th>Native Amount</th>
              <th className="text-right">Master Valuation</th>
            </tr>
          </thead>
          <tbody>
            {filteredTransactions.map((tx) => {
              const isIncome = tx.transactionType === 'INCOME';
              const conv = convertCurrency(tx.originalAmount, tx.originalCurrency, masterCurrency, rates);

              return (
                <tr key={tx.transactionId} className="ledger-row">
                  <td className="mono text-muted">{tx.transactionDate}</td>
                  <td>
                    <div className="payee-name">{tx.merchantOrPayee}</div>
                    <div className="payee-acc mono text-muted">{tx.accountId}</div>
                  </td>
                  <td>
                    <div className="category-title">{tx.categoryName || tx.categoryId}</div>
                    <span className="tier-tag-sub mono">{tx.cashFlowTier}</span>
                  </td>
                  <td>
                    {tx.isTaxDeductible ? (
                      <div className="tax-badge-wrap">
                        <span className="badge badge-gold">💼 DEDUCTIBLE</span>
                        {tx.taxInvoiceNumber && (
                          <span className="badge badge-purple mono">🧾 {tx.taxInvoiceNumber}</span>
                        )}
                      </div>
                    ) : tx.categoryId === 'CAT_TAX_STATUTORY_PROVISIONAL' ? (
                      <span className="badge badge-cyan">🏛️ STATUTORY REMITTANCE</span>
                    ) : (
                      <span className="text-muted text-xs">—</span>
                    )}
                  </td>
                  <td className="mono">
                    <span className={isIncome ? 'text-emerald' : 'text-primary'}>
                      {tx.originalCurrency} {Math.abs(tx.originalAmount).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                    </span>
                  </td>
                  <td className="mono text-right">
                    <strong className={isIncome ? 'text-emerald' : 'text-primary'}>
                      {isIncome ? '+' : ''}{conv.formatted}
                    </strong>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
};
