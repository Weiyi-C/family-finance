import api from './index'
import type { RegisterRequest, LoginRequest, TokenResponse, RegisterResponse } from '@/types'

export function register(data: RegisterRequest) {
  return api.post<RegisterResponse>('/auth/register', data)
}

export function login(data: LoginRequest) {
  return api.post<TokenResponse>('/auth/login', data)
}

export function refreshToken(refresh_token: string) {
  return api.post<TokenResponse>('/auth/refresh', { refresh_token })
}

export function logout(refresh_token: string) {
  return api.post('/auth/logout', { refresh_token })
}
