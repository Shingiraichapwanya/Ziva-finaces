import React from 'react';
import { BudgetEnvelope, MasterCurrency, ExchangeRates } from '../../types/finance';
import { convertCurrency } from '../../services/currency';
import { PieChart, AlertTriangle, CheckCircle2, ShieldCheck } from 'lucide-react';

interface BudgetsViewProps {
  envelopes: BudgetEnvelope[];
  masterCurrency: MasterCurrency;
  rates: ExchangeRates;
}

export const BudgetsView: React.FC<BudgetsViewProps> = ({ envelopes, masterCurrency, rates }) => {
  const totalPlannedZar = envelopes.reduce((s, e) => s + e.plannedAmountZar, 0);
  const totalSpentZar = envelopes.reduce((s, e) => s + e.actualSpentZar, 0);
  const totalVarianceZar = totalPlannedZar - totalSpentZar;

  const plannedMaster = convertCurrency(totalPlannedZar, 'ZAR', masterCurrency, rates);
  const spentMaster = convertCurrency(totalSpentZar, 'ZAR', masterCurrency, rates);
  const varianceMaster = convertCurrency(totalVarianceZar, 'ZAR', masterCurrency, rates);

  return (
    <div className="budgets-view animate-fade-in">
      <div className="page-header">
        <div>
          <h2>Zero-Based Budgeting Envelopes</h2>
          <p className="page-subtitle">
            Every Rand, Dollar, and ZiG assigned to a concrete envelope or savings sink.
          </p>
        </div>
      </div>

      {/* Macro ZBB Overview */}
      <div className="budget-macro-grid">
        <div className="glass-panel macro-stat-card">
          <div className="stat-label">Total Monthly Target</div>
          <div className="stat-value mono">{plannedMaster.formatted}</div>
          <div className="stat-hint text-muted">Zero-Based Envelope Sum</div>
        </div>

        <div className="glass-panel macro-stat-card">
          <div className="stat-label">Actual Consumed to Date</div>
          <div className="stat-value mono text-gold">{spentMaster.formatted}</div>
          <div className="stat-hint text-emerald">
            {totalPlannedZar > 0 ? Math.round((totalSpentZar / totalPlannedZar) * 100) : 0}% of Monthly Capital
          </div>
        </div>

        <div className="glass-panel macro-stat-card">
          <div className="stat-label">Remaining Safe Variance</div>
          <div className={`stat-value mono ${totalVarianceZar >= 0 ? 'text-emerald' : 'text-rose'}`}>
            {varianceMaster.formatted}
          </div>
          <div className="stat-hint text-muted">
            {totalVarianceZar >= 0 ? 'Surplus Available' : 'Deficit Offset Required'}
          </div>
        </div>
      </div>

      {/* Envelopes Grid */}
      <div className="envelopes-grid">
        {envelopes.map((env) => {
          const plannedConv = convertCurrency(env.plannedAmountZar, 'ZAR', masterCurrency, rates);
          const spentConv = convertCurrency(env.actualSpentZar, 'ZAR', masterCurrency, rates);
          const varianceConv = convertCurrency(env.varianceZar, 'ZAR', masterCurrency, rates);

          const isOver = env.budgetStatus === 'OVER_BUDGET';
          const isNear = env.budgetStatus === 'NEAR_LIMIT';

          return (
            <div key={env.categoryId} className={`glass-panel envelope-card ${isOver ? 'card-over-budget' : ''}`}>
              <div className="envelope-card-top">
                <div>
                  <div className="env-category-group mono text-muted">{env.categoryGroup}</div>
                  <h4 className="env-title">{env.categoryName}</h4>
                </div>
                <div>
                  {isOver ? (
                    <span className="badge badge-rose">
                      <AlertTriangle size={12} /> OVER BUDGET
                    </span>
                  ) : isNear ? (
                    <span className="badge badge-gold">⚠️ NEAR LIMIT</span>
                  ) : (
                    <span className="badge badge-emerald">
                      <CheckCircle2 size={12} /> ON TRACK
                    </span>
                  )}
                </div>
              </div>

              {/* Progress Bar */}
              <div className="env-meter-wrap">
                <div className="meter-track">
                  <div
                    className={`meter-fill ${isOver ? 'bg-rose' : isNear ? 'bg-gold' : 'bg-emerald'}`}
                    style={{ width: `${Math.min(100, env.pctConsumed)}%` }}
                  />
                </div>
                <div className="env-pct mono">{env.pctConsumed.toFixed(1)}% Consumed</div>
              </div>

              {/* Card Figures */}
              <div className="env-figures-grid">
                <div>
                  <div className="fig-label">Target</div>
                  <div className="fig-val mono">{plannedConv.formatted}</div>
                </div>
                <div>
                  <div className="fig-label">Spent</div>
                  <div className="fig-val mono text-primary">{spentConv.formatted}</div>
                </div>
                <div>
                  <div className="fig-label">Remaining</div>
                  <div className={`fig-val mono ${env.varianceZar >= 0 ? 'text-emerald' : 'text-rose'}`}>
                    {varianceConv.formatted}
                  </div>
                </div>
              </div>

              <div className="env-footer-meta">
                <span className="mono text-muted text-xs">Tier: {env.cashFlowTier}</span>
                {env.isFixedObligation && (
                  <span className="badge badge-indigo badge-compact">Fixed Obligation</span>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
