import React from 'react';
import { MasterCurrency } from '../../types/finance';
import { Settings, ShieldCheck, Database, GitBranch, HardDrive, RefreshCw } from 'lucide-react';

interface SettingsViewProps {
  masterCurrency: MasterCurrency;
  onSelectCurrency: (c: MasterCurrency) => void;
  isOnline: boolean;
  onManualSync: () => void;
}

export const SettingsView: React.FC<SettingsViewProps> = ({
  masterCurrency,
  onSelectCurrency,
  isOnline,
  onManualSync
}) => {
  return (
    <div className="settings-view animate-fade-in">
      <div className="page-header">
        <div>
          <h2>System Settings & Cloud Diagnostics</h2>
          <p className="page-subtitle">
            Configure viewing preferences, monitor BigQuery warehouse telemetry, and manage offline data caches.
          </p>
        </div>
      </div>

      <div className="settings-grid">
        {/* Card 1: Viewing Preferences */}
        <div className="glass-panel settings-card">
          <div className="card-header-row">
            <Settings size={20} className="text-gold" />
            <h3>Viewing & Currency Preferences</h3>
          </div>

          <div className="setting-item">
            <div>
              <div className="setting-title">Default Master Currency</div>
              <div className="setting-desc">Primary currency used to normalize all balances and reports</div>
            </div>
            <select
              className="settings-select mono"
              value={masterCurrency}
              onChange={(e) => onSelectCurrency(e.target.value as MasterCurrency)}
            >
              <option value="ZAR">🇿🇦 ZAR - South African Rand</option>
              <option value="USD">🇺🇸 USD - United States Dollar</option>
              <option value="ZiG">🇿🇼 ZiG - Zimbabwe Gold</option>
            </select>
          </div>

          <div className="setting-item">
            <div>
              <div className="setting-title">Zimbabwe Rate Evaluation Model</div>
              <div className="setting-desc">Evaluate ZiG operational spending against parallel or official rates</div>
            </div>
            <span className="badge badge-cyan mono">MARKET_PARALLEL (Recommended)</span>
          </div>
        </div>

        {/* Card 2: BigQuery Warehouse Connection */}
        <div className="glass-panel settings-card">
          <div className="card-header-row">
            <Database size={20} className="text-cyan" />
            <h3>Google BigQuery Warehouse</h3>
          </div>

          <div className="config-list mono">
            <div className="config-row">
              <span className="config-key">GCP Project ID:</span>
              <span className="config-val">budget-tracker-507418</span>
            </div>
            <div className="config-row">
              <span className="config-key">Primary Dataset:</span>
              <span className="config-val">personal_finance</span>
            </div>
            <div className="config-row">
              <span className="config-key">Compute Region:</span>
              <span className="config-val">africa-south1 (Johannesburg)</span>
            </div>
            <div className="config-row">
              <span className="config-key">Ingestion Pipeline:</span>
              <span className="config-val text-emerald">Load Jobs (Free Sandbox Compatible)</span>
            </div>
            <div className="config-row">
              <span className="config-key">Active Reporting Views:</span>
              <span className="config-val text-gold">7 Production Views</span>
            </div>
          </div>
        </div>

        {/* Card 3: Offline-First Cache & Storage */}
        <div className="glass-panel settings-card">
          <div className="card-header-row">
            <HardDrive size={20} className="text-emerald" />
            <h3>Offline Cache & Storage</h3>
          </div>

          <div className="setting-item">
            <div>
              <div className="setting-title">IndexedDB Local Cache</div>
              <div className="setting-desc">Local encrypted client database for instant offline access</div>
            </div>
            <span className="badge badge-emerald">ACTIVE & HYDRATED</span>
          </div>

          <div className="setting-item">
            <div>
              <div className="setting-title">Network Synchronization</div>
              <div className="setting-desc">Status: {isOnline ? 'Online • 0 pending mutations' : 'Offline • Queue active'}</div>
            </div>
            <button type="button" className="btn btn-secondary" onClick={onManualSync}>
              <RefreshCw size={14} />
              <span>Force Re-sync</span>
            </button>
          </div>
        </div>

        {/* Card 4: GitHub Versioning */}
        <div className="glass-panel settings-card">
          <div className="card-header-row">
            <GitBranch size={20} className="text-purple" />
            <h3>Version Control & GitHub Sync</h3>
          </div>

          <div className="config-list mono">
            <div className="config-row">
              <span className="config-key">Active Branch:</span>
              <span className="config-val text-gold">feature/command-center-and-wealth-suite</span>
            </div>
            <div className="config-row">
              <span className="config-key">Integration Branch:</span>
              <span className="config-val">dev</span>
            </div>
            <div className="config-row">
              <span className="config-key">Stable Release:</span>
              <span className="config-val text-emerald">main</span>
            </div>
            <div className="config-row">
              <span className="config-key">Workflow Automation:</span>
              <span className="config-val">scripts/git_workflow.ps1</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
