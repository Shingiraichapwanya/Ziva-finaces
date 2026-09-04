/**
 * currency.ts - Multi-Currency Conversion Engine
 * Implements precision cross-currency conversion across ZAR, USD, and ZiG.
 */

import { CurrencyCode, MasterCurrency, ExchangeRates } from '../types/finance';

export const DEFAULT_RATES: ExchangeRates = {
  USD_TO_ZAR: 18.25,
  ZAR_TO_USD: 1 / 18.25,
  USD_TO_ZIG_OFFICIAL: 13.85,
  ZIG_TO_USD_OFFICIAL: 1 / 13.85,
  USD_TO_ZIG_PARALLEL: 24.50,
  ZIG_TO_USD_PARALLEL: 1 / 24.50,
  ZAR_TO_ZIG_OFFICIAL: 13.85 / 18.25, // ~0.7589
  ZAR_TO_ZIG_PARALLEL: 24.50 / 18.25, // ~1.3425
  lastUpdated: '2026-09-04 11:30 UTC'
};

export interface ConversionResult {
  amount: number;
  formatted: string;
  currency: MasterCurrency;
  symbol: string;
  nativeAnnotation: string;
}

export function getCurrencySymbol(code: MasterCurrency): string {
  switch (code) {
    case 'ZAR': return 'R';
    case 'USD': return '$';
    case 'ZiG': return 'ZiG';
  }
}

/**
 * Converts any native amount into the target Master Currency view.
 */
export function convertCurrency(
  nativeAmount: number,
  nativeCurrency: CurrencyCode,
  targetCurrency: MasterCurrency,
  rates: ExchangeRates = DEFAULT_RATES,
  useParallelRate: boolean = true
): ConversionResult {
  const symbol = getCurrencySymbol(targetCurrency);

  // Identity
  if (nativeCurrency === targetCurrency) {
    return {
      amount: nativeAmount,
      formatted: `${symbol} ${Math.abs(nativeAmount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`,
      currency: targetCurrency,
      symbol,
      nativeAnnotation: ''
    };
  }

  // Step 1: Normalize native amount to USD base
  let amountInUsd = 0;
  if (nativeCurrency === 'USD') {
    amountInUsd = nativeAmount;
  } else if (nativeCurrency === 'ZAR') {
    amountInUsd = nativeAmount * rates.ZAR_TO_USD;
  } else if (nativeCurrency === 'ZiG') {
    const zigToUsd = useParallelRate ? rates.ZIG_TO_USD_PARALLEL : rates.ZIG_TO_USD_OFFICIAL;
    amountInUsd = nativeAmount * zigToUsd;
  }

  // Step 2: Convert USD base into Target Master Currency
  let finalTargetAmount = 0;
  if (targetCurrency === 'USD') {
    finalTargetAmount = amountInUsd;
  } else if (targetCurrency === 'ZAR') {
    finalTargetAmount = amountInUsd * rates.USD_TO_ZAR;
  } else if (targetCurrency === 'ZiG') {
    const usdToZig = useParallelRate ? rates.USD_TO_ZIG_PARALLEL : rates.USD_TO_ZIG_OFFICIAL;
    finalTargetAmount = amountInUsd * usdToZig;
  }

  const nativeSymbol = getCurrencySymbol(nativeCurrency);
  const nativeFormatted = `${nativeSymbol} ${Math.abs(nativeAmount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

  return {
    amount: finalTargetAmount,
    formatted: `${symbol} ${Math.abs(finalTargetAmount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`,
    currency: targetCurrency,
    symbol,
    nativeAnnotation: `[Orig: ${nativeFormatted}]`
  };
}
