import api from './index'
import type {
  Channel, ChannelCreate, ChannelUpdate,
  Platform, PlatformCreate, PlatformUpdate,
} from '@/types'

export function getChannels() {
  return api.get<Channel[]>('/channels')
}

export function createChannel(data: ChannelCreate) {
  return api.post<Channel>('/channels', data)
}

export function updateChannel(channelId: number, data: ChannelUpdate) {
  return api.put<Channel>(`/channels/${channelId}`, data)
}

export function deleteChannel(channelId: number) {
  return api.delete(`/channels/${channelId}`)
}

export function getPlatforms(type?: string) {
  return api.get<Platform[]>('/platforms', { params: type ? { type } : {} })
}

export function createPlatform(data: PlatformCreate) {
  return api.post<Platform>('/platforms', data)
}

export function updatePlatform(platformId: number, data: PlatformUpdate) {
  return api.put<Platform>(`/platforms/${platformId}`, data)
}

export function deletePlatform(platformId: number) {
  return api.delete(`/platforms/${platformId}`)
}
