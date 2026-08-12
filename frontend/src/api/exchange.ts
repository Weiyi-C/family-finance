import api from './index'

export interface ExchangeRate {
  id: number
  base_currency: string
  target_currency: string
  rate: number
  rate_type: string
  source: string
  rate_date: string
}

export function getExchangeRates(params?: {
  base_currency?: string
  target_currency?: string
  rate_date?: string
}) {
  return api.get<ExchangeRate[]>('/api/exchange-rates', { params })
}

export function convertCurrency(params: {
  amount: number
  from_currency: string
  to_currency: string
  rate_date?: string
}) {
  return api.get<{ amount: number; converted: number; rate: number; rate_date: string }>(
    '/api/exchange-rates/convert',
    { params }
  )
}

export function createExchangeRate(data: {
  base_currency: string
  target_currency: string
  rate: number
  rate_date: string
  rate_type?: string
  source?: string
}) {
  return api.post<ExchangeRate>('/api/exchange-rates', data)
}
