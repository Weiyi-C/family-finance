import api from './index'

export interface ErrorLog {
  id: number
  level: string
  endpoint: string
  method: string
  user_id: number | null
  error_type: string
  message: string
  created_at: string
}

export interface SlowQuery {
  id: number
  endpoint: string
  query_text: string | null
  duration_ms: number
  user_id: number | null
  created_at: string
}

export interface MonitorSummary {
  today_errors: number
  week_slow_queries: number
  recent_errors: Array<{
    level: string
    endpoint: string
    message: string | null
    created_at: string
  }>
}

export function getMonitorSummary() {
  return api.get<MonitorSummary>('/monitor/summary')
}

export function getErrorLogs(params: { level?: string; limit?: number } = {}) {
  return api.get<ErrorLog[]>('/monitor/errors', { params })
}

export function getSlowQueries(params: { min_ms?: number; limit?: number } = {}) {
  return api.get<SlowQuery[]>('/monitor/slow-queries', { params })
}
