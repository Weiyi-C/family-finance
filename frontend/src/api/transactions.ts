import api from './index'
import type { Transaction, TransactionCreate, TransactionUpdate, TransactionListParams } from '@/types'

export interface PaginatedResponse<T> {
  items: T[]
  total: number
  page: number
  page_size: number
  pages: number
}

export function getTransactions(params: TransactionListParams = {}) {
  return api.get<PaginatedResponse<Transaction>>('/transactions', { params })
}

export function createTransaction(data: TransactionCreate) {
  return api.post<Transaction>('/transactions', data)
}

export function getTransaction(txnId: number) {
  return api.get<Transaction>(`/transactions/${txnId}`)
}

export function updateTransaction(txnId: number, data: TransactionUpdate) {
  return api.put<Transaction>(`/transactions/${txnId}`, data)
}

export function deleteTransaction(txnId: number) {
  return api.delete(`/transactions/${txnId}`)
}
