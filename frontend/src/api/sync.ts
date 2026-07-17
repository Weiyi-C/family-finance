import api from './index'

export interface SyncChange {
  seq: number
  table_name: string
  record_id: number
  operation: string
  version: number
  change_data: Record<string, unknown> | null
  changed_at: string | null
}

export interface SyncPullResponse {
  changes: SyncChange[]
  current_seq: number
  has_more: boolean
}

export function syncPull(clientId: string, lastSeq = 0, limit = 100) {
  return api.post<SyncPullResponse>('/sync/pull', { client_id: clientId, last_seq: lastSeq, limit })
}

export function syncPush(clientId: string, changes: Record<string, unknown>[]) {
  return api.post('/sync/push', { client_id: clientId, changes })
}
