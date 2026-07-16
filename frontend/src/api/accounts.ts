import api from './index'
import type { PaymentAccount, AccountCreate, AccountUpdate, AccountBalance } from '@/types'

export function getAccounts(includeHidden = false) {
  return api.get<PaymentAccount[]>('/accounts', { params: { include_hidden: includeHidden } })
}

export function createAccount(data: AccountCreate) {
  return api.post<PaymentAccount>('/accounts', data)
}

export function getAccount(accountId: number) {
  return api.get<PaymentAccount>(`/accounts/${accountId}`)
}

export function updateAccount(accountId: number, data: AccountUpdate) {
  return api.put<PaymentAccount>(`/accounts/${accountId}`, data)
}

export function deleteAccount(accountId: number) {
  return api.delete<PaymentAccount>(`/accounts/${accountId}`)
}

export function getAccountBalance(accountId: number) {
  return api.get<AccountBalance>(`/accounts/${accountId}/balance`)
}
