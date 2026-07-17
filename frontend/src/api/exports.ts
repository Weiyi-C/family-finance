import api from './index'

export function exportTransactions(format: 'csv' | 'json' = 'csv') {
  return api.get('/export/transactions', { params: { format }, responseType: 'blob' })
}

export function exportAccounts() {
  return api.get('/export/accounts', { responseType: 'blob' })
}

export function exportCategories() {
  return api.get('/export/categories', { responseType: 'blob' })
}
