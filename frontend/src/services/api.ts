/**
 * api.ts - Type-Safe BigQuery REST API Client for Ziva Finance
 * Connects frontend to the Express BigQuery backend running on /api
 */

import {
  Account,
  BudgetEnvelope,
  ExchangeRates,
  TaxQuarterSchedule,
  Transaction
} from '../types/finance';

const API_BASE = '/api';

export interface HealthStatus {
  status: string;
  project: string;
  dataset: string;
  location: string;
  timestamp: string;
}

export const financeApi = {
  /**
   * Check connection status to BigQuery backend
   */
  async checkHealth(): Promise<HealthStatus> {
    const res = await fetch(`${API_BASE}/health`, { signal: AbortSignal.timeout(4000) });
    if (!res.ok) throw new Error(`Health check failed: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch latest live effective exchange rates
   */
  async getExchangeRates(): Promise<ExchangeRates> {
    const res = await fetch(`${API_BASE}/rates`, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) throw new Error(`Failed to fetch exchange rates: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch accounts and calculated live balances
   */
  async getAccounts(): Promise<Account[]> {
    const res = await fetch(`${API_BASE}/accounts`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch accounts: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch primary ledger transactions
   */
  async getTransactions(limit = 100): Promise<Transaction[]> {
    const res = await fetch(`${API_BASE}/transactions?limit=${limit}`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch transactions: ${res.statusText}`);
    return res.json();
  },

  /**
   * Ingest a new transaction (manual entry or receipt scan) into BigQuery
   */
  async createTransaction(transactionData: Partial<Transaction>): Promise<{ success: boolean; transactionId: string; record: any }> {
    const res = await fetch(`${API_BASE}/transactions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(transactionData),
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) throw new Error(`Failed to ingest transaction into BigQuery: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch budget envelopes vs actuals
   */
  async getBudgetEnvelopes(): Promise<BudgetEnvelope[]> {
    const res = await fetch(`${API_BASE}/budgets`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch budgets: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch quarterly tax liability schedule
   */
  async getTaxSchedule(): Promise<TaxQuarterSchedule | null> {
    const res = await fetch(`${API_BASE}/tax-schedule`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch tax schedule: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch vault holdings
   */
  async getVaultHoldings(): Promise<any[]> {
    const res = await fetch(`${API_BASE}/vault`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch vault holdings: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch daily burn metrics
   */
  async getDailyBurnMetrics(): Promise<any[]> {
    const res = await fetch(`${API_BASE}/burn-rate`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch burn rate: ${res.statusText}`);
    return res.json();
  }
};
