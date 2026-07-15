import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('access_token') || '')
  const isLoggedIn = ref(!!token.value)

  function setToken(newToken: string) {
    token.value = newToken
    isLoggedIn.value = true
    localStorage.setItem('access_token', newToken)
  }

  function logout() {
    token.value = ''
    isLoggedIn.value = false
    localStorage.removeItem('access_token')
  }

  return { token, isLoggedIn, setToken, logout }
})
