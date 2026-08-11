import api from './index'

export interface AIProvider {
  id: string
  name: string
  models: string[]
  default_model: string
}

export interface AISettings {
  provider: string
  api_key_masked: string
  base_url: string
  model: string
  enabled: boolean
}

export interface AISettingsUpdate {
  provider: string
  api_key: string
  base_url?: string
  model?: string
  enabled: boolean
}

export interface AITransaction {
  transaction_time?: string
  merchant?: string
  description?: string
  amount?: number
  type?: string
  payment_method?: string
  category_hint?: string
}

export function getAIProviders() {
  return api.get<AIProvider[]>('/ai/providers')
}

export function getAISettings() {
  return api.get<AISettings>('/ai/settings')
}

export function updateAISettings(data: AISettingsUpdate) {
  return api.put('/ai/settings', data)
}

export function deleteAISettings() {
  return api.delete('/ai/settings')
}

export function testAIConnection() {
  return api.post('/ai/test')
}

export function aiParseFile(file: File) {
  const formData = new FormData()
  formData.append('file', file)
  return api.post<{ transactions: AITransaction[]; count: number; source: string }>(
    '/ai/parse-file',
    formData,
    { headers: { 'Content-Type': 'multipart/form-data' } }
  )
}

export function aiParseImage(file: File) {
  const formData = new FormData()
  formData.append('file', file)
  return api.post<{ transactions: AITransaction[]; count: number; source: string }>(
    '/ai/parse-image',
    formData,
    { headers: { 'Content-Type': 'multipart/form-data' } }
  )
}

export interface AISuggestion {
  id: number
  family_id: number
  type: 'tag' | 'duplicate' | 'periodic' | 'category'
  status: 'pending' | 'accepted' | 'rejected'
  transaction_ids: number[] | null
  suggestion: Record<string, unknown>
  reason: string | null
  created_at: string
  resolved_at: string | null
}

export interface AISuggestionListResponse {
  suggestions: AISuggestion[]
  total: number
  pending_count: number
}

export function triggerAnalysis() {
  return api.post<{ message: string; count: number }>('/ai/analyze')
}

export function getAISuggestions(params?: { type?: string; status?: string }) {
  return api.get<AISuggestionListResponse>('/ai/suggestions', { params })
}

export function acceptSuggestion(id: number) {
  return api.post(`/ai/suggestions/${id}/accept`)
}

export function rejectSuggestion(id: number) {
  return api.post(`/ai/suggestions/${id}/reject`)
}

export function batchActionSuggestions(ids: number[], action: 'accept' | 'reject') {
  return api.post('/ai/suggestions/batch-action', { ids, action })
}
