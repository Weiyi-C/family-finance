import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { login as apiLogin, register as apiRegister, logout as apiLogout } from '@/api/auth'
import { getMe } from '@/api/users'
import type { LoginRequest, RegisterRequest, UserMe } from '@/types'

export const useAuthStore = defineStore('auth', () => {
  const accessToken = ref(localStorage.getItem('access_token') || '')
  const refreshTokenVal = ref(localStorage.getItem('refresh_token') || '')
  const user = ref<UserMe | null>(null)
  const isLoggedIn = computed(() => !!accessToken.value)

  function setTokens(access: string, refresh: string) {
    accessToken.value = access
    refreshTokenVal.value = refresh
    localStorage.setItem('access_token', access)
    localStorage.setItem('refresh_token', refresh)
  }

  async function login(data: LoginRequest) {
    const res = await apiLogin(data)
    setTokens(res.data.access_token, res.data.refresh_token)
    await fetchUser()
  }

  async function register(data: RegisterRequest) {
    const res = await apiRegister(data)
    setTokens(res.data.tokens.access_token, res.data.tokens.refresh_token)
    user.value = {
      id: res.data.user.id,
      nickname: res.data.user.nickname,
      phone: res.data.user.phone,
      avatar_url: res.data.user.avatar_url,
      role: res.data.user.role,
      family_id: res.data.user.family_id,
    }
  }

  async function fetchUser() {
    try {
      const res = await getMe()
      user.value = res.data
    } catch {
      user.value = null
    }
  }

  async function logout() {
    try {
      if (refreshTokenVal.value) {
        await apiLogout(refreshTokenVal.value)
      }
    } catch {
      // ignore
    }
    accessToken.value = ''
    refreshTokenVal.value = ''
    user.value = null
    localStorage.removeItem('access_token')
    localStorage.removeItem('refresh_token')
  }

  async function init() {
    if (accessToken.value) {
      await fetchUser()
    }
  }

  return { accessToken, refreshTokenVal, user, isLoggedIn, login, register, fetchUser, logout, init }
})
