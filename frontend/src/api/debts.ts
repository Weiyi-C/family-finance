import api from './index'
import type { Debt, DebtCreate, DebtUpdate, RepaymentCreate, RepaymentResponse } from '@/types'

export function getDebts(params: { type?: string; status?: string } = {}) {
  return api.get<Debt[]>('/debts', { params })
}

export function createDebt(data: DebtCreate) {
  return api.post<Debt>('/debts', data)
}

export function getDebt(debtId: number) {
  return api.get<Debt>(`/debts/${debtId}`)
}

export function updateDebt(debtId: number, data: DebtUpdate) {
  return api.put<Debt>(`/debts/${debtId}`, data)
}

export function addRepayment(debtId: number, data: RepaymentCreate) {
  return api.post<RepaymentResponse>(`/debts/${debtId}/repayments`, data)
}

export function deleteDebt(debtId: number) {
  return api.delete(`/debts/${debtId}`)
}
