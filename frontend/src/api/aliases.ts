import api from './index'

export interface MerchantAlias {
  id: number
  family_id: number | null
  original_name: string
  alias_name: string
  category_id: number | null
  sub_category_id: number | null
  platform_id: number | null
  hit_count: number
  is_active: boolean
}

export interface AliasCreate {
  original_name: string
  alias_name: string
  category_id?: number
  sub_category_id?: number
  platform_id?: number
}

export interface AliasUpdate {
  alias_name?: string
  category_id?: number
  sub_category_id?: number
  platform_id?: number
}

export function getAliases() {
  return api.get<MerchantAlias[]>('/aliases')
}

export function createAlias(data: AliasCreate) {
  return api.post<MerchantAlias>('/aliases', data)
}

export function updateAlias(aliasId: number, data: AliasUpdate) {
  return api.put<MerchantAlias>(`/aliases/${aliasId}`, data)
}

export function deleteAlias(aliasId: number) {
  return api.delete(`/aliases/${aliasId}`)
}
