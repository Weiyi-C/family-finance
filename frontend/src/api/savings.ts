import api from './index'
import type { SavingsGoal, SavingsGoalCreate, SavingsGoalUpdate, DepositRequest } from '@/types'

export function getSavings(params: { status?: string } = {}) {
  return api.get<SavingsGoal[]>('/savings', { params })
}

export function createSavings(data: SavingsGoalCreate) {
  return api.post<SavingsGoal>('/savings', data)
}

export function getSavingsGoal(goalId: number) {
  return api.get<SavingsGoal>(`/savings/${goalId}`)
}

export function updateSavingsGoal(goalId: number, data: SavingsGoalUpdate) {
  return api.put<SavingsGoal>(`/savings/${goalId}`, data)
}

export function depositSavings(goalId: number, data: DepositRequest) {
  return api.post<SavingsGoal>(`/savings/${goalId}/deposit`, data)
}

export function abandonSavings(goalId: number) {
  return api.post<SavingsGoal>(`/savings/${goalId}/abandon`)
}

export function deleteSavings(goalId: number) {
  return api.delete(`/savings/${goalId}`)
}
