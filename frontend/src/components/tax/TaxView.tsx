import React from 'react';
import { TaxQuarterSchedule, Transaction, MasterCurrency, ExchangeRates } from '../../types/finance';
import { convertCurrency } from '../../services/currency';
import { Landmark, ShieldCheck, FileCheck, CheckCircle2, AlertCircle } from 'lucide-react';

interface TaxViewProps {
  taxSchedule: TaxQuarterSchedule;
  transactions: Transaction[];
  masterCurrency: MasterCurrency;
  rates: ExchangeRates;
}

export const TaxView: React.FC<TaxViewProps> = ({
  taxSchedule,
  transactions,
  masterCurrency,
  rates
}) => {
  const deductibleTransactions = transactions.filter((t) => t.isTaxDeductible);

  const grossConv = convertCurrency(taxSchedule.grossTaxableInflowZar, 'ZAR', masterCurrency, rates);
  const deductionsConv = convertCurrency(taxSchedule.totalAllowableDeductionsZar, 'ZAR', masterCurrency, rates);
  const netTaxableConv = convertCurrency(taxSchedule.netTaxableIncomeZar, 'ZAR', masterCurrency, rates);
  const estimatedTaxConv = convertCurrency(taxSchedule.estimatedTaxLiabilityZar, 'ZAR', masterCurrency, rates);
  const actualPaidConv = convertCurrency(taxSchedule.actualTaxPaidZar, 'ZAR', masterCurrency, rates);
  const outstandingConv = convertCurrency(taxSchedule.netTaxOutstandingZar, 'ZAR', masterCurrency, rates);

  const isCreditSurplus = taxSchedule.netTaxOutstandingZar < 0;

  return (
    <div className="tax-view animate-fade-in">
      <div className="page-header">
        <div>
          <h2>Tax Compliance & Business Offsets (SARS / ZIMRA)</h2>
          <p className="page-subtitle">
            Quarterly provisional tax liability calculations derived from BigQuery view <code className="mono">v_quarterly_tax_liability_schedule</code>.
          </p>
        </div>
        <div>
          <span className="badge badge-emerald">
            <CheckCircle2 size={14} /> 2026-Q3 Status: {taxSchedule.taxSettlementStatus}
          </span>
        </div>
      </div>

      {/* Primary Tax Calculation Meter */}
      <div className="glass-panel tax-meter-card">
        <div className="tax-calc-grid">
          <div className="calc-block">
            <div className="calc-label">Gross Taxable Revenue</div>
            <div className="calc-val mono">{grossConv.formatted}</div>
            <div className="calc-hint text-muted">Consulting & Inflows</div>
          </div>

          <div className="calc-operator">−</div>

          <div className="calc-block">
            <div className="calc-label">Total Allowable Deductions</div>
            <div className="calc-val mono text-emerald">{deductionsConv.formatted}</div>
            <div className="calc-hint text-emerald">Tech Hardware, Cloud, Fibre</div>
          </div>

          <div className="calc-operator">=</div>

          <div className="calc-block">
            <div className="calc-label">Net Taxable Income</div>
            <div className="calc-val mono text-gold">{netTaxableConv.formatted}</div>
            <div className="calc-hint text-gold">Provisional Base</div>
          </div>

          <div className="calc-operator">× 27% =</div>

          <div className="calc-block calc-block-highlight">
            <div className="calc-label">Est. Tax Liability</div>
            <div className="calc-val mono text-primary">{estimatedTaxConv.formatted}</div>
            <div className="calc-hint text-muted">Benchmark Provisional</div>
          </div>
        </div>

        {/* Remittance & Settlement Summary */}
        <div className="tax-settlement-bar">
          <div>
            <span className="settle-label">Actual Statutory Remittances:</span>{' '}
            <strong className="mono">{actualPaidConv.formatted}</strong>{' '}
            <span className="text-muted text-xs">(IRP6 / QPD payments to SARS/ZIMRA)</span>
          </div>
          <div>
            <span className="settle-label">Net Settlement Position:</span>{' '}
            <strong className={`mono ${isCreditSurplus ? 'text-emerald' : 'text-rose'}`}>
              {isCreditSurplus ? `+${Math.abs(taxSchedule.netTaxOutstandingZar).toFixed(2)} (Credit Surplus)` : outstandingConv.formatted}
            </strong>
          </div>
        </div>
      </div>

      {/* Itemized Audit Schedule */}
      <div className="glass-panel audit-table-wrapper">
        <div className="section-title-bar">
          <div>
            <h3>Itemized Tax-Deductible Business Expense Schedule</h3>
            <p className="section-subtitle">
              Audit-ready breakdown corresponding to <code className="mono">v_tax_deductible_expenses_audit</code>
            </p>
          </div>
          <span className="badge badge-gold">{deductibleTransactions.length} Audit Invoices</span>
        </div>

        <table className="ledger-table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Merchant / Vendor</th>
              <th>Tax Line Item</th>
              <th>Tax Invoice Ref</th>
              <th>Native Spend</th>
              <th className="text-right">Deductible Offset</th>
            </tr>
          </thead>
          <tbody>
            {deductibleTransactions.map((tx) => {
              const deductibleConv = convertCurrency(
                tx.taxDeductibleAmountZar || Math.abs(tx.originalAmount),
                'ZAR',
                masterCurrency,
                rates
              );

              return (
                <tr key={tx.transactionId} className="ledger-row">
                  <td className="mono text-muted">{tx.transactionDate}</td>
                  <td>
                    <div className="payee-name">{tx.merchantOrPayee}</div>
                    <div className="payee-acc text-xs text-muted">{tx.categoryName}</div>
                  </td>
                  <td>
                    <span className="badge badge-gold mono">
                      {tx.categoryId === 'CAT_PROD_TECH_HARDWARE' ? 'PRODUCTIVITY_HARDWARE' :
                       tx.categoryId === 'CAT_PROD_SOFTWARE_TOOLS' ? 'BUSINESS_SOFTWARE' :
                       tx.categoryId === 'CAT_ALLOC_INTERNET' ? 'HOME_OFFICE_DEDUCTION' : 'TAX_DEDUCTIBLE'}
                    </span>
                  </td>
                  <td>
                    {tx.taxInvoiceNumber ? (
                      <span className="badge badge-purple mono">🧾 {tx.taxInvoiceNumber}</span>
                    ) : (
                      <span className="badge badge-rose text-xs">Missing Invoice Ref</span>
                    )}
                  </td>
                  <td className="mono">
                    {tx.originalCurrency} {Math.abs(tx.originalAmount).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                  </td>
                  <td className="mono text-right text-emerald">
                    +{deductibleConv.formatted}
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
