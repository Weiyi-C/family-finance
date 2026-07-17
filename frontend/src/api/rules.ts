import api from './index'

export interface AutomationRule {
  id: number
  family_id: number | null
  name: string
  conditions: Record<string, unknown>
  actions: Record<string, unknown>
  stage: string
  priority: number
  is_active: boolean
  hit_count: number
}

export interface RuleCreate {
  name: string
  conditions: Record<string, unknown>
  actions: Record<string, unknown>
  stage?: string
  priority?: number
}

export interface RuleUpdate {
  name?: string
  conditions?: Record<string, unknown>
  actions?: Record<string, unknown>
  stage?: string
  priority?: number
  is_active?: boolean
}

export function getRules() {
  return api.get<AutomationRule[]>('/rules')
}

export function createRule(data: RuleCreate) {
  return api.post<AutomationRule>('/rules', data)
}

export function updateRule(ruleId: number, data: RuleUpdate) {
  return api.put<AutomationRule>(`/rules/${ruleId}`, data)
}

export function deleteRule(ruleId: number) {
  return api.delete(`/rules/${ruleId}`)
}

export function testRule(data: { conditions: Record<string, unknown>; test_data: Record<string, unknown> }) {
  return api.post<{ matched: boolean }>('/rules/test', data)
}
