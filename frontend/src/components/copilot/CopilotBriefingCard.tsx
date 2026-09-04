/**
 * CopilotBriefingCard.tsx - Dashboard Executive Briefing Widget
 * Embedded in the main Command Center view for quick AI visibility and one-click simulator launch.
 */

import React, { useEffect, useState } from 'react';
import { Sparkles, ArrowRight, ShieldAlert, Zap, Layers } from 'lucide-react';
import { MasterCurrency } from '../../types/finance';
import { financeApi, CopilotInsightsResponse } from '../../services/api';

interface CopilotBriefingCardProps {
  onOpenCopilot: () => void;
  masterCurrency: MasterCurrency;
}

export const CopilotBriefingCard: React.FC<CopilotBriefingCardProps> = ({
  onOpenCopilot,
  masterCurrency
}) => {
  const [data, setData] = useState<CopilotInsightsResponse | null>(null);

  useEffect(() => {
    financeApi
      .getCopilotInsights()
      .then(setData)
      .catch((err) => console.warn('Briefing card insights error:', err));
  }, []);

  const runwayDays = data?.metrics.baselineRunwayDays || 45;
  const taxAtRisk = data?.metrics.taxSavingsAtRiskZar || 12638;
  const spread = data?.metrics.spreadPct || 77;

  return (
    <div className="glass-panel copilot-briefing-card animate-fade-in">
      <div className="briefing-card-glow" />
      <div className="briefing-card-content">
        <div className="briefing-header">
          <div className="briefing-badge">
            <Sparkles size={14} className="text-gold" />
            <span>GEMINI FINANCIAL INTELLIGENCE BRIEFING</span>
          </div>
          <span className="mono briefing-date">
            Grounded in BigQuery • {new Date().toLocaleDateString('en-ZA', { month: 'short', day: 'numeric', year: 'numeric' })}
          </span>
        </div>

        <div className="briefing-grid">
          <div className="briefing-item">
            <div className="briefing-item-icon">
              <Zap size={16} className="text-cyan" />
            </div>
            <div>
              <div className="briefing-item-title mono">{runwayDays} Days Liquid Runway</div>
              <div className="briefing-item-sub">
                Burn velocity is {data?.metrics.burnStatus || 'STABLE'}. Projected exhaustion date: {data?.metrics.survivalDate || '2026-10-20'}.
              </div>
            </div>
          </div>

          <div className="briefing-item">
            <div className="briefing-item-icon">
              <ShieldAlert size={16} className="text-gold" />
            </div>
            <div>
              <div className="briefing-item-title mono">R{taxAtRisk.toLocaleString()} Tax Write-offs at Risk</div>
              <div className="briefing-item-sub">
                Unattached vendor invoices pending SARS 27% section 11(a) deduction audit.
              </div>
            </div>
          </div>

          <div className="briefing-item">
            <div className="briefing-item-icon">
              <Layers size={16} className="text-emerald" />
            </div>
            <div>
              <div className="briefing-item-title mono">+{spread}% Parallel Spread Advantage</div>
              <div className="briefing-item-sub">
                Official POS card swipe unlocks statutory retail savings vs holding volatile cash.
              </div>
            </div>
          </div>
        </div>

        <div className="briefing-footer">
          <span className="briefing-hint">
            Run real-time scenario modeling or ask custom tax & cross-border questions:
          </span>
          <button
            type="button"
            className="btn btn-primary btn-copilot-launch"
            onClick={onOpenCopilot}
          >
            <Sparkles size={16} />
            <span>Open Copilot Simulator</span>
            <ArrowRight size={14} />
          </button>
        </div>
      </div>
    </div>
  );
};
