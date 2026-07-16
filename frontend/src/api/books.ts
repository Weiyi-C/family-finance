import api from './index'
import type { AccountBook, BookCreate, BookUpdate } from '@/types'

export function getBooks(includeArchived = false) {
  return api.get<AccountBook[]>('/books', { params: { include_archived: includeArchived } })
}

export function createBook(data: BookCreate) {
  return api.post<AccountBook>('/books', data)
}

export function getBook(bookId: number) {
  return api.get<AccountBook>(`/books/${bookId}`)
}

export function updateBook(bookId: number, data: BookUpdate) {
  return api.put<AccountBook>(`/books/${bookId}`, data)
}

export function deleteBook(bookId: number) {
  return api.delete<AccountBook>(`/books/${bookId}`)
}
