import api from './index'
import type { Category, CategoryCreate, CategoryUpdate } from '@/types'

export function getCategories(type?: string) {
  return api.get<Category[]>('/categories', { params: type ? { type } : {} })
}

export function getCategoriesFlat(type?: string) {
  return api.get<Category[]>('/categories/flat', { params: type ? { type } : {} })
}

export function createCategory(data: CategoryCreate) {
  return api.post<Category>('/categories', data)
}

export function updateCategory(categoryId: number, data: CategoryUpdate) {
  return api.put<Category>(`/categories/${categoryId}`, data)
}

export function deleteCategory(categoryId: number) {
  return api.delete(`/categories/${categoryId}`)
}
