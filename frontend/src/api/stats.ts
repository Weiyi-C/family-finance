import api from './index'
import type { StatsSummary, CategoryStats, MonthlyStats, DailyStats, MerchantRank } from '@/types'

export interface StatsParams {
  start?: string
  end?: string
  type?: string
  book_id?: number
  limit?: number
  year?: number
}

export function getSummary(params: StatsParams = {}) {
  return api.get<StatsSummary>('/stats/summary', { params })
}

export function getByCategory(params: StatsParams = {}) {
  return api.get<CategoryStats[]>('/stats/by-category', { params })
}

export function getByMonth(params: StatsParams = {}) {
  return api.get<MonthlyStats[]>('/stats/by-month', { params })
}

export function getByDay(params: StatsParams = {}) {
  return api.get<DailyStats[]>('/stats/by-day', { params })
}

export function getMerchantRanking(params: StatsParams = {}) {
  return api.get<MerchantRank[]>('/stats/merchant-ranking', { params })
}
