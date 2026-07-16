import api from './index'
import type { UserMe } from '@/types'

export function getMe() {
  return api.get<UserMe>('/users/me')
}
