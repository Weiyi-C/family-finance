import api from './index'

export interface Notification {
  id: number
  user_id: number
  family_id: number
  type: string
  title: string
  content: string | null
  related_id: number | null
  related_type: string | null
  is_read: boolean
  read_at: string | null
  channel: string
  send_status: string
  created_at: string | null
}

export function getNotifications(params: { is_read?: boolean; limit?: number } = {}) {
  return api.get<Notification[]>('/notifications', { params })
}

export function getUnreadCount() {
  return api.get<{ count: number }>('/notifications/unread')
}

export function markNotificationRead(notifId: number) {
  return api.put(`/notifications/${notifId}/read`)
}

export function markAllNotificationsRead() {
  return api.put('/notifications/read-all')
}
