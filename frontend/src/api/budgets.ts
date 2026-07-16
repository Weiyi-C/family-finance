import api from './index'
import type { Budget, BudgetCreate, BudgetUpdate, BudgetUsage } from '@/types'

export function getBudgets(params: { year?: number; month?: number } = {}) {
  return api.get<Budget[]>('/budgets', { params })
}

export function createBudget(data: BudgetCreate) {
  return api.post<Budget>('/budgets', data)
}

export function getBudget(budgetId: number) {
  return api.get<Budget>(`/budgets/${budgetId}`)
}

export function updateBudget(budgetId: number, data: BudgetUpdate) {
  return api.put<Budget>(`/budgets/${budgetId}`, data)
}

export function deleteBudget(budgetId: number) {
  return api.delete(`/budgets/${budgetId}`)
}

export function getBudgetUsage(budgetId: number) {
  return api.get<BudgetUsage>(`/budgets/${budgetId}/usage`)
}
