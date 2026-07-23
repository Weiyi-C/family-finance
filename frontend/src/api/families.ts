import api from './index'

export interface FamilyMember {
  id: number
  nickname: string
  phone: string | null
  avatar_url: string | null
  role: string
}

export interface FamilyInfo {
  id: number
  name: string
  created_by: number
  created_at: string
}

export function getCurrentFamily() {
  return api.get<FamilyInfo>('/families/current')
}

export function updateFamily(data: { name: string }) {
  return api.put<FamilyInfo>('/families/current', data)
}

export function getMembers() {
  return api.get<FamilyMember[]>('/families/members')
}

export function addMember(data: { phone: string; role?: string }) {
  return api.post('/families/members', data)
}

export function updateMember(memberId: number, data: { role: string }) {
  return api.put(`/families/members/${memberId}`, data)
}

export function removeMember(memberId: number) {
  return api.delete(`/families/members/${memberId}`)
}
