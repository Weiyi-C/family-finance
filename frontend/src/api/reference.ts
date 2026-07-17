import api from './index'

export interface Bank {
  id: number
  name: string
  code: string
  short_name: string
  color: string | null
}

export interface AccountTemplate {
  id: number
  type_code: string
  name: string
  icon: string | null
  group_name: string
  is_credit: boolean
  has_credit_limit: boolean
  has_billing_day: boolean
  has_due_day: boolean
}

export function getBanks() {
  return api.get<Bank[]>('/banks')
}

export function getAccountTemplates() {
  return api.get<AccountTemplate[]>('/account-templates')
}
