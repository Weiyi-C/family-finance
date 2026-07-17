import api from './index'

export interface CreditBill {
  id: number
  account_id: number
  family_id: number
  bill_year: number
  bill_month: number
  billing_date: string
  due_date: string
  total_amount: number
  paid_amount: number
  min_payment: number
  status: string
}

export function getCreditBills(accountId?: number) {
  return api.get<CreditBill[]>('/credit-bills', { params: accountId ? { account_id: accountId } : {} })
}

export function getCreditBill(billId: number) {
  return api.get<CreditBill>(`/credit-bills/${billId}`)
}

export function payCreditBill(billId: number, amount: number) {
  return api.post<CreditBill>(`/credit-bills/${billId}/pay`, { amount })
}

export function getCreditBillSummary() {
  return api.get<{ total_due: number; bill_count: number }>('/credit-bills/summary')
}
