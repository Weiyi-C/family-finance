import api from './index'
import type { RecurringTransaction, RecurringCreate, RecurringUpdate, RecurringLog } from '@/types'

export function getRecurring(params: { is_active?: boolean } = {}) {
  return api.get<RecurringTransaction[]>('/recurring', { params })
}

export function createRecurring(data: RecurringCreate) {
  return api.post<RecurringTransaction>('/recurring', data)
}

export function getRecurringById(recurringId: number) {
  return api.get<RecurringTransaction>(`/recurring/${recurringId}`)
}

export function updateRecurring(recurringId: number, data: RecurringUpdate) {
  return api.put<RecurringTransaction>(`/recurring/${recurringId}`, data)
}

export function deleteRecurring(recurringId: number) {
  return api.delete(`/recurring/${recurringId}`)
}

export function generateRecurring(recurringId: number) {
  return api.post<RecurringLog>(`/recurring/${recurringId}/generate`)
}

export function getRecurringLogs(recurringId: number) {
  return api.get<RecurringLog[]>(`/recurring/${recurringId}/logs`)
}
