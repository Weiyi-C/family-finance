import api from './index'
import type { Tag, TagCreate, TagUpdate } from '@/types'

export function getTags() {
  return api.get<Tag[]>('/tags')
}

export function createTag(data: TagCreate) {
  return api.post<Tag>('/tags', data)
}

export function updateTag(tagId: number, data: TagUpdate) {
  return api.put<Tag>(`/tags/${tagId}`, data)
}

export function deleteTag(tagId: number) {
  return api.delete(`/tags/${tagId}`)
}
