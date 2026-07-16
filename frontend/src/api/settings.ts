import api from './index'
import type { UserSettings, SettingsUpdate, Notification } from '@/types'

export function getSettings() {
  return api.get<UserSettings>('/settings')
}

export function updateSettings(data: SettingsUpdate) {
  return api.put<UserSettings>('/settings', data)
}

export function getNotifications(params: { is_read?: boolean } = {}) {
  return api.get<Notification[]>('/notifications', { params })
}

export function markNotificationRead(notifId: number) {
  return api.put<Notification>(`/notifications/${notifId}/read`)
}

export function markAllNotificationsRead() {
  return api.put('/notifications/read-all')
}
