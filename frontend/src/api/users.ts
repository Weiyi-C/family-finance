import api from './index'
import type { UserMe } from '@/types'

export function getMe() {
  return api.get<UserMe>('/users/me')
}

export function updateMe(data: { nickname?: string; phone?: string }) {
  return api.put<UserMe>('/users/me', data)
}

export function changePassword(data: { old_password: string; new_password: string }) {
  return api.put('/users/me/password', data)
}
