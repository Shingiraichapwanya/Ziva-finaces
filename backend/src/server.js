/**
 * server.js - Express API Server for Ziva Finance
 * Streams live BigQuery analytics and ledger mutations to the Financial Command Center.
 */

import express from 'express';
import cors from 'cors';
import {
  BQ_CONFIG,
  getExchangeRates,
  getAccounts,
  getTransactions,
  getBudgetEnvelopes,
  getTaxSchedule,
  getDailyBurnMetrics,
  getVaultHoldings,
  insertTransaction
} from './bigquery.js';

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// Health & Status endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ONLINE',
    project: BQ_CONFIG.projectId,
    dataset: BQ_CONFIG.datasetId,
    location: BQ_CONFIG.location,
    timestamp: new Date().toISOString()
  });
});

// Live FX rates
app.get('/api/rates', async (req, res) => {
  try {
    const rates = await getExchangeRates();
    res.json(rates);
  } catch (error) {
    console.error('Error fetching FX rates:', error);
    res.status(500).json({ error: error.message });
  }
});

// Accounts & Live balances
app.get('/api/accounts', async (req, res) => {
  try {
    const accounts = await getAccounts();
    res.json(accounts);
  } catch (error) {
    console.error('Error fetching accounts:', error);
    res.status(500).json({ error: error.message });
  }
});

// Ledger Transactions
app.get('/api/transactions', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit || '100', 10);
    const transactions = await getTransactions(limit);
    res.json(transactions);
  } catch (error) {
    console.error('Error fetching transactions:', error);
    res.status(500).json({ error: error.message });
  }
});

// Insert new transaction (Manual entry or receipt scan)
app.post('/api/transactions', async (req, res) => {
  try {
    const result = await insertTransaction(req.body);
    res.json(result);
  } catch (error) {
    console.error('Error inserting transaction:', error);
    res.status(500).json({ error: error.message });
  }
});

// Budget Envelopes vs Actual
app.get('/api/budgets', async (req, res) => {
  try {
    const envelopes = await getBudgetEnvelopes();
    res.json(envelopes);
  } catch (error) {
    console.error('Error fetching budgets:', error);
    res.status(500).json({ error: error.message });
  }
});

// Tax Schedule
app.get('/api/tax-schedule', async (req, res) => {
  try {
    const schedule = await getTaxSchedule();
    res.json(schedule);
  } catch (error) {
    console.error('Error fetching tax schedule:', error);
    res.status(500).json({ error: error.message });
  }
});

// Vault holdings & Net Worth
app.get('/api/vault', async (req, res) => {
  try {
    const vault = await getVaultHoldings();
    res.json(vault);
  } catch (error) {
    console.error('Error fetching vault holdings:', error);
    res.status(500).json({ error: error.message });
  }
});

// Daily Burn Metrics
app.get('/api/burn-rate', async (req, res) => {
  try {
    const burn = await getDailyBurnMetrics();
    res.json(burn);
  } catch (error) {
    console.error('Error fetching burn metrics:', error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`=======================================================`);
  console.log(` Ziva Finance BigQuery API Server running on port ${PORT}`);
  console.log(` Connected to GCP Project: ${BQ_CONFIG.projectId}`);
  console.log(` Dataset: ${BQ_CONFIG.datasetId} (${BQ_CONFIG.location})`);
  console.log(`=======================================================`);
});
