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
