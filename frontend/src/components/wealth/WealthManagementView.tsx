import React, { useState } from 'react';
import {
  PredictiveBurnMetrics,
  TaxShieldOpportunity,
  ArbitrageSignal,
  InvestmentCounter,
  MasterCurrency,
  ExchangeRates
} from '../../types/finance';
import { convertCurrency } from '../../services/currency';
import {
  Flame,
  ShieldCheck,
  ArrowRightLeft,
  Briefcase,
  Sliders,
  Sparkles,
  TrendingUp,
  AlertTriangle,
  Lightbulb,
  Info
} from 'lucide-react';

interface WealthManagementViewProps {
  burnMetrics: PredictiveBurnMetrics;
  taxOpportunities: TaxShieldOpportunity[];
  arbitrageSignals: ArbitrageSignal[];
  investments: InvestmentCounter[];
  masterCurrency: MasterCurrency;
  rates: ExchangeRates;
}

export const WealthManagementView: React.FC<WealthManagementViewProps> = ({
  burnMetrics,
  taxOpportunities,
  arbitrageSignals,
  investments,
  masterCurrency,
  rates
}) => {
  const [activeTab, setActiveTab] = useState<'burn' | 'tax-shield' | 'arbitrage' | 'investments'>('burn');

  // Interactive Cutback Simulator State
  const [diningCutback, setDiningCutback] = useState(0); // 0 to 100%
  const [subscriptionsCutback, setSubscriptionsCutback] = useState(0);
  const [discretionaryCutback, setDiscretionaryCutback] = useState(0);

  // Calculate dynamic adjusted burn rate based on slider adjustments
  // Baseline daily burn: R1420. Discretionary is ~R620.
  const diningDailyZar = 150;
  const subscriptionsDailyZar = 80;
  const generalDiscretionaryDailyZar = 390;

  const savedDailyZar =
    (diningDailyZar * (diningCutback / 100)) +
    (subscriptionsDailyZar * (subscriptionsCutback / 100)) +
    (generalDiscretionaryDailyZar * (discretionaryCutback / 100));

  const adjustedDailyBurnZar = Math.max(800, burnMetrics.averageDailyBurnZar - savedDailyZar);
  const adjustedRunwayDays = Math.floor(burnMetrics.liquidReserveBalanceZar / adjustedDailyBurnZar);
  const additionalDaysGained = Math.max(0, adjustedRunwayDays - burnMetrics.baselineRunwayDays);

  const burnRateConv = convertCurrency(adjustedDailyBurnZar, 'ZAR', masterCurrency, rates);
  const liquidReserveConv = convertCurrency(burnMetrics.liquidReserveBalanceZar, 'ZAR', masterCurrency, rates);

  return (
    <div className="wealth-view animate-fade-in">
      <div className="page-header">
        <div>
          <h2>Wealth Management & Intelligence Suite</h2>
          <p className="page-subtitle">
            Capital runway modeling, tax liability minimization, currency spread arbitrage, and Gemini-powered VFEX/JSE intelligence.
          </p>
        </div>
      </div>

      {/* Sub-Navigation Tabs */}
      <div className="wealth-subnav">
        <button
          type="button"
          className={`wealth-tab-btn ${activeTab === 'burn' ? 'active' : ''}`}
          onClick={() => setActiveTab('burn')}
        >
          <Flame size={16} />
          <span>Predictive Burn</span>
        </button>
        <button
          type="button"
          className={`wealth-tab-btn ${activeTab === 'tax-shield' ? 'active' : ''}`}
          onClick={() => setActiveTab('tax-shield')}
        >
          <ShieldCheck size={16} />
          <span>Tax Shield (27% Offsets)</span>
        </button>
        <button
          type="button"
          className={`wealth-tab-btn ${activeTab === 'arbitrage' ? 'active' : ''}`}
          onClick={() => setActiveTab('arbitrage')}
        >
          <ArrowRightLeft size={16} />
          <span>Currency Arbitrage</span>
        </button>
        <button
          type="button"
          className={`wealth-tab-btn ${activeTab === 'investments' ? 'active' : ''}`}
          onClick={() => setActiveTab('investments')}
        >
          <Sparkles size={16} />
          <span>Investments (VFEX + JSE)</span>
        </button>
      </div>

      {/* TAB 1: PREDICTIVE BURN */}
      {activeTab === 'burn' && (
        <div className="wealth-panel-content">
          <div className="burn-hero-grid">
            <div className="glass-panel burn-stat-card">
              <div className="stat-label">Estimated Liquid Runway</div>
              <div className="burn-big-num mono text-rose">
                {adjustedRunwayDays} <span className="burn-unit">Days</span>
              </div>
              <div className="stat-hint">
                {additionalDaysGained > 0 ? (
                  <span className="text-emerald">+{additionalDaysGained} days gained via simulation cuts!</span>
                ) : (
                  <span>Based on 30-day trailing daily burn</span>
                )}
              </div>
            </div>

            <div className="glass-panel burn-stat-card">
              <div className="stat-label">Adjusted Daily Burn Velocity</div>
              <div className="burn-big-num mono text-gold">{burnRateConv.formatted} / day</div>
              <div className="stat-hint text-muted">
                Liquid Capital Base: {liquidReserveConv.formatted} (Notice ≤ 32d)
              </div>
            </div>

            <div className="glass-panel burn-stat-card">
              <div className="stat-label">Essential Fixed Bills Runway</div>
              <div className="burn-big-num mono text-emerald">
                {burnMetrics.fixedObligationsRunwayDays} <span className="burn-unit">Days</span>
              </div>
              <div className="stat-hint text-muted">Assuming zero discretionary spend</div>
            </div>
          </div>

          {/* Interactive Scenario Simulator */}
          <div className="glass-panel simulator-card">
            <div className="section-title-bar">
              <div>
                <h3>Interactive Runway Scenario Simulator</h3>
                <p className="section-subtitle">
                  Tweak category discretionary spending cuts below to see how many days of survival runway you unlock.
                </p>
              </div>
              <span className="badge badge-gold">
                <Sliders size={14} /> Real-Time Modeling
              </span>
            </div>

            <div className="sliders-grid">
              <div className="slider-group">
                <div className="slider-label-row">
                  <span>Dining & Coffee Cutback</span>
                  <span className="slider-val mono">{diningCutback}%</span>
                </div>
                <input
                  type="range"
                  min="0"
                  max="100"
                  step="10"
                  value={diningCutback}
                  onChange={(e) => setDiningCutback(parseInt(e.target.value))}
                  className="scenario-slider"
                />
              </div>

              <div className="slider-group">
                <div className="slider-label-row">
                  <span>Streaming & Subscriptions Cutback</span>
                  <span className="slider-val mono">{subscriptionsCutback}%</span>
                </div>
                <input
                  type="range"
                  min="0"
                  max="100"
                  step="10"
                  value={subscriptionsCutback}
                  onChange={(e) => setSubscriptionsCutback(parseInt(e.target.value))}
                  className="scenario-slider"
                />
              </div>

              <div className="slider-group">
                <div className="slider-label-row">
                  <span>General Discretionary & Incidentals</span>
                  <span className="slider-val mono">{discretionaryCutback}%</span>
                </div>
                <input
                  type="range"
                  min="0"
                  max="100"
                  step="10"
                  value={discretionaryCutback}
                  onChange={(e) => setDiscretionaryCutback(parseInt(e.target.value))}
                  className="scenario-slider"
                />
              </div>
            </div>
          </div>
        </div>
      )}

      {/* TAB 2: TAX SHIELD */}
      {activeTab === 'tax-shield' && (
        <div className="wealth-panel-content">
          <div className="tax-shield-intro glass-panel">
            <div className="intro-icon bg-emerald">
              <ShieldCheck size={28} className="text-emerald" />
            </div>
            <div>
              <h3>Ziva Tax Shield Optimization Engine</h3>
              <p>
                Continuously analyzes your gross consulting inflows against allowable business write-offs under South African and Zimbabwean tax codes. Every R1,000 in qualifying business equipment, cloud infra, or home office expenses reduces your provisional tax bill by <strong>R270.00 (27.00% benchmark)</strong>.
              </p>
            </div>
          </div>

          <div className="opportunities-list">
            {taxOpportunities.map((opp) => {
              const currentConv = convertCurrency(opp.currentClaimedZar, 'ZAR', masterCurrency, rates);
              const targetConv = convertCurrency(opp.targetThresholdZar, 'ZAR', masterCurrency, rates);
              const savingsConv = convertCurrency(opp.taxSavingsZar, 'ZAR', masterCurrency, rates);

              return (
                <div key={opp.id} className="glass-panel opportunity-card">
                  <div className="opp-header">
                    <div>
                      <span className="badge badge-gold">{opp.categoryName}</span>
                      <h4 className="opp-title">{opp.title}</h4>
                    </div>
                    <div className="text-right">
                      <div className="opp-tax-saving mono text-emerald">+{savingsConv.formatted}</div>
                      <div className="opp-tax-label">Tax Saved at 27%</div>
                    </div>
                  </div>

                  <p className="opp-recommendation">{opp.recommendation}</p>

                  <div className="opp-footer">
                    <div className="opp-threshold-bar">
                      <span className="text-muted text-xs mono">
                        Claimed: {currentConv.formatted} / Benchmark: {targetConv.formatted}
                      </span>
                    </div>
                    <span className="badge badge-emerald">Strategy: Tax Year 2026</span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* TAB 3: CURRENCY ARBITRAGE */}
      {activeTab === 'arbitrage' && (
        <div className="wealth-panel-content">
          <div className="arbitrage-spread-hero glass-panel">
            <div className="spread-badge-box">
              <span className="spread-pct mono text-cyan">+76.9%</span>
              <span className="spread-caption">Parallel Rate Premium over Official RBZ Benchmark</span>
            </div>
            <div className="spread-rates-grid">
              <div>
                <div className="rate-sub">RBZ Official Interbank</div>
                <div className="rate-bold mono">1 USD = ZiG {rates.USD_TO_ZIG_OFFICIAL.toFixed(2)}</div>
              </div>
              <div>
                <div className="rate-sub">Market Clearing Parallel</div>
                <div className="rate-bold mono text-cyan">1 USD = ZiG {rates.USD_TO_ZIG_PARALLEL.toFixed(2)}</div>
              </div>
            </div>
          </div>

          <div className="signals-grid">
            {arbitrageSignals.map((sig) => (
              <div key={sig.id} className="glass-panel signal-card">
                <div className="signal-top">
                  <span className="badge badge-cyan">{sig.pair}</span>
                  <span className="badge badge-gold">{sig.actionBadge}</span>
                </div>
                <h4 className="signal-title">{sig.actionBadge}</h4>
                <p className="signal-desc">{sig.recommendation}</p>
                <div className="signal-footer mono text-muted text-xs">
                  Official: {sig.officialRate} | Market: {sig.parallelRate} (Spread: +{sig.spreadPct}%)
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* TAB 4: INVESTMENTS (VFEX + JSE) WITH GEMINI */}
      {activeTab === 'investments' && (
        <div className="wealth-panel-content">
          {/* Gemini Advisory Header Card */}
          <div className="glass-panel gemini-advisory-banner">
            <div className="gemini-icon-pill">
              <Sparkles size={20} className="text-purple" />
              <span>Gemini Investment Intelligence</span>
            </div>
            <p className="gemini-lead-insight">
              "Cross-border portfolio analysis: Holding pure export USD counters on the Victoria Falls Stock Exchange (Padenga, Caledonia) delivers an effective hedge against regional currency depreciation. On the JSE, Satrix S&P 500 and Capitec Bank provide steady compounding with dual-currency diversification."
            </p>
            <div className="gemini-disclaimer">
              <Info size={14} />
              <span>
                Educational market advisory only. Does not constitute personalized financial or investment advice.
              </span>
            </div>
          </div>

          {/* Holdings Grid */}
          <div className="investments-table-wrapper glass-panel">
            <div className="section-title-bar">
              <div>
                <h3>Victoria Falls Stock Exchange (VFEX) & Johannesburg Stock Exchange (JSE)</h3>
                <p className="section-subtitle">Multi-market equities and ETF holdings tracked in Long-Term Vault</p>
              </div>
            </div>

            <div className="holdings-grid">
              {investments.map((stock) => {
                const isVfex = stock.market === 'VFEX';
                const conv = convertCurrency(
                  stock.holdingValueNative,
                  stock.nativeCurrency,
                  masterCurrency,
                  rates
                );

                return (
                  <div key={stock.symbol} className="glass-panel stock-card">
                    <div className="stock-card-top">
                      <div>
                        <div className="stock-symbol-row">
                          <span className="stock-symbol mono">{stock.symbol}</span>
                          <span className={`badge ${isVfex ? 'badge-cyan' : 'badge-gold'}`}>
                            {stock.market} ({stock.nativeCurrency})
                          </span>
                        </div>
                        <div className="stock-name">{stock.name}</div>
                      </div>
                      <div className="text-right">
                        <div className="stock-price mono">
                          {stock.nativeCurrency === 'USD' ? '$' : 'R'} {stock.lastPrice.toFixed(2)}
                        </div>
                        <div className={`stock-change mono text-xs ${stock.change24h >= 0 ? 'text-emerald' : 'text-rose'}`}>
                          {stock.change24h >= 0 ? '+' : ''}{stock.change24h}%
                        </div>
                      </div>
                    </div>

                    <div className="stock-holding-row">
                      <div className="holding-units text-muted text-xs mono">
                        Holding: {stock.holdingUnits.toLocaleString()} units
                      </div>
                      <div className="holding-master-val mono">
                        Valuation: <strong>{conv.formatted}</strong>
                      </div>
                    </div>

                    {/* Gemini Reasoning Pill */}
                    <div className="gemini-pill-box">
                      <div className="gemini-pill-header">
                        <Sparkles size={12} className="text-purple" />
                        <span>Gemini Context</span>
                        <span className="badge badge-purple badge-compact">Defensive: {stock.geminiAdvisory.defensiveScore}</span>
                      </div>
                      <p className="gemini-pill-text">{stock.geminiAdvisory.macroInsight}</p>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
