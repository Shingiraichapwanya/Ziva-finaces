import React, { useState } from 'react';
import { Transaction, CurrencyCode } from '../../types/finance';
import { X, Camera, Upload, Check, Sparkles, FileText } from 'lucide-react';

interface ReceiptScanModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSaveReceiptTransaction: (tx: Transaction) => void;
}

export const ReceiptScanModal: React.FC<ReceiptScanModalProps> = ({
  isOpen,
  onClose,
  onSaveReceiptTransaction
}) => {
  const [merchant, setMerchant] = useState('iStore Sandton City');
  const [amount, setAmount] = useState('3200');
  const [currency, setCurrency] = useState<CurrencyCode>('ZAR');
  const [invoiceNumber, setInvoiceNumber] = useState('INV-ISTORE-9941');
  const [isTaxDeductible, setIsTaxDeductible] = useState(true);
  const [receiptSimulated, setReceiptSimulated] = useState(true);

  if (!isOpen) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const num = parseFloat(amount) || 0;

    const newTx: Transaction = {
      transactionId: `TX_SCAN_${Date.now().toString().slice(-6)}`,
      transactionTimestamp: new Date().toISOString(),
      transactionDate: new Date().toISOString().split('T')[0],
      localTimezone: 'Africa/Johannesburg',
      accountId: currency === 'USD' ? 'ACC_ZW_ECOCASH_USD' : currency === 'ZiG' ? 'ACC_ZW_ECOCASH_ZIG' : 'ACC_ZA_CAPITEC_DAILY',
      cashFlowTier: 'DAILY_SPENDING',
      categoryId: isTaxDeductible ? 'CAT_PROD_TECH_HARDWARE' : 'CAT_DAILY_INCIDENTAL',
      categoryName: isTaxDeductible ? 'Productivity Tech & Work Hardware' : 'Micro-Cash & Incidentals',
      transactionType: 'EXPENSE',
      originalAmount: -num,
      originalCurrency: currency,
      reportingAmountUsd: currency === 'USD' ? -num : -num * (1 / 18.25),
      reportingAmountZar: currency === 'ZAR' ? -num : -num * 18.25,
      appliedExchangeRateUsd: 1 / 18.25,
      appliedExchangeRateZar: 1.0,
      rateTypeApplied: 'OFFICIAL_INTERBANK',
      merchantOrPayee: merchant,
      paymentMethod: 'DEBIT_CARD',
      isTaxDeductible,
      taxDeductibleAmountZar: isTaxDeductible ? num : undefined,
      taxInvoiceNumber: invoiceNumber || undefined,
      tags: ['receipt-scan', currency.toLowerCase(), isTaxDeductible ? 'tax-deductible' : 'personal'],
      isSynced: true
    };

    onSaveReceiptTransaction(newTx);
    onClose();
  };

  return (
    <div className="modal-backdrop animate-fade-in" onClick={onClose}>
      <div className="glass-panel modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div className="modal-title-wrap">
            <Camera size={20} className="text-gold" />
            <h3>Scan & Archive Tax Receipt</h3>
          </div>
          <button type="button" className="btn-close" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="modal-body">
          {/* Simulated WebP Camera Capture Preview */}
          <div className="receipt-preview-box">
            <div className="receipt-preview-inner">
              <FileText size={36} className="text-gold" />
              <div className="receipt-info-text">
                <strong>RECEIPT DETECTED: {invoiceNumber}</strong>
                <span className="mono text-muted text-xs">Compressed WebP (142 KB) • Stored in IndexedDB</span>
              </div>
            </div>
          </div>

          <div className="form-row">
            <div className="form-col">
              <label className="form-label">Merchant / Payee</label>
              <input
                type="text"
                className="form-input"
                value={merchant}
                onChange={(e) => setMerchant(e.target.value)}
                required
              />
            </div>
            <div className="form-col">
              <label className="form-label">Tax Invoice Reference</label>
              <input
                type="text"
                className="form-input mono"
                value={invoiceNumber}
                onChange={(e) => setInvoiceNumber(e.target.value)}
                placeholder="INV-..."
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-col">
              <label className="form-label">Amount</label>
              <input
                type="number"
                step="0.01"
                className="form-input mono"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                required
              />
            </div>
            <div className="form-col">
              <label className="form-label">Currency</label>
              <select
                className="form-input mono"
                value={currency}
                onChange={(e) => setCurrency(e.target.value as CurrencyCode)}
              >
                <option value="ZAR">ZAR (R)</option>
                <option value="USD">USD ($)</option>
                <option value="ZiG">ZiG</option>
              </select>
            </div>
          </div>

          {/* Tax Compliance Toggle */}
          <label className="tax-checkbox-box">
            <input
              type="checkbox"
              checked={isTaxDeductible}
              onChange={(e) => setIsTaxDeductible(e.target.checked)}
            />
            <div>
              <strong>Qualifies as Tax-Deductible Business Expense</strong>
              <div className="text-muted text-xs">
                Offsets gross income at 27% provisional tax benchmark in BigQuery view <code className="mono">v_quarterly_tax_liability_schedule</code>.
              </div>
            </div>
          </label>

          <div className="modal-actions">
            <button type="button" className="btn btn-secondary" onClick={onClose}>
              Cancel
            </button>
            <button type="submit" className="btn btn-primary">
              <Check size={16} />
              <span>Save & Queue for Warehouse</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
