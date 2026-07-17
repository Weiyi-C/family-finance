import api from './index'

export interface BillImport {
  id: number
  family_id: number
  book_id: number
  source: string
  file_url: string | null
  file_format: string | null
  status: string
  total_rows: number
  parsed_count: number
  matched_count: number
  new_count: number
}

export interface BillImportItem {
  id: number
  import_id: number
  raw_data: Record<string, unknown>
  parsed_amount: number | null
  parsed_time: string | null
  parsed_merchant: string | null
  parsed_category: string | null
  matched_txn_id: number | null
  action: string
}

export interface ImportCreate {
  book_id: number
  source: string
  file_format?: string
  items: Record<string, unknown>[]
}

export function getImports() {
  return api.get<BillImport[]>('/imports')
}

export function createImport(data: ImportCreate) {
  return api.post<BillImport>('/imports', data)
}

export function getImport(importId: number) {
  return api.get<BillImport>(`/imports/${importId}`)
}

export function getImportItems(importId: number) {
  return api.get<BillImportItem[]>(`/imports/${importId}/items`)
}

export function deleteImport(importId: number) {
  return api.delete(`/imports/${importId}`)
}
