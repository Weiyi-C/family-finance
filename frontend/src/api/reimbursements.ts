import api from './index'
import type {
  Reimbursement, ReimbursementCreate, ReimbursementUpdate, ReceiveRequest,
} from '@/types'

export function getReimbursements(params: { status?: string } = {}) {
  return api.get<Reimbursement[]>('/reimbursements', { params })
}

export function createReimbursement(data: ReimbursementCreate) {
  return api.post<Reimbursement>('/reimbursements', data)
}

export function getReimbursement(reimbId: number) {
  return api.get<Reimbursement>(`/reimbursements/${reimbId}`)
}

export function updateReimbursement(reimbId: number, data: ReimbursementUpdate) {
  return api.put<Reimbursement>(`/reimbursements/${reimbId}`, data)
}

export function submitReimbursement(reimbId: number) {
  return api.post<Reimbursement>(`/reimbursements/${reimbId}/submit`)
}

export function approveReimbursement(reimbId: number) {
  return api.post<Reimbursement>(`/reimbursements/${reimbId}/approve`)
}

export function receiveReimbursement(reimbId: number, data: ReceiveRequest) {
  return api.post<Reimbursement>(`/reimbursements/${reimbId}/receive`, data)
}

export function deleteReimbursement(reimbId: number) {
  return api.delete(`/reimbursements/${reimbId}`)
}
