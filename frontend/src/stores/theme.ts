import { defineStore } from 'pinia'
import { ref, watch, computed } from 'vue'

export type ThemeMode = 'light' | 'dark' | 'auto'
export type SidebarTheme = 'dark' | 'light'

export interface ThemePreset {
  name: string
  label: string
  primary: string
}

export const themePresets: ThemePreset[] = [
  { name: 'blue', label: '经典蓝', primary: '#409eff' },
  { name: 'green', label: '清新绿', primary: '#67c23a' },
  { name: 'purple', label: '优雅紫', primary: '#8b5cf6' },
  { name: 'orange', label: '温暖橙', primary: '#e6a23c' },
  { name: 'pink', label: '樱花粉', primary: '#ec4899' },
  { name: 'teal', label: '薄荷青', primary: '#14b8a6' },
  { name: 'red', label: '中国红', primary: '#ef4444' },
  { name: 'indigo', label: '靛蓝', primary: '#6366f1' },
]

export const useThemeStore = defineStore('theme', () => {
  const mode = ref<ThemeMode>('light')
  const sidebarTheme = ref<SidebarTheme>('dark')
  const preset = ref<string>('blue')
  const customPrimary = ref<string>('')

  const effectivePrimary = computed(() => {
    if (customPrimary.value) return customPrimary.value
    const p = themePresets.find(t => t.name === preset.value)
    return p?.primary || '#409eff'
  })

  function applyTheme() {
    const html = document.documentElement

    // 深浅模式
    const isDark = mode.value === 'dark' ||
      (mode.value === 'auto' && window.matchMedia('(prefers-color-scheme: dark)').matches)
    html.classList.toggle('dark', isDark)

    // 侧边栏主题
    html.setAttribute('data-sidebar-theme', sidebarTheme.value)

    // 主色调
    html.style.setProperty('--color-primary', effectivePrimary.value)
    // 计算浅色变体（混入白色）
    html.style.setProperty('--color-primary-light', lightenColor(effectivePrimary.value, 0.2))
    html.style.setProperty('--color-primary-dark', darkenColor(effectivePrimary.value, 0.1))
    // Element Plus 主色覆盖
    html.style.setProperty('--el-color-primary', effectivePrimary.value)
  }

  function init() {
    // 从 localStorage 恢复
    const saved = localStorage.getItem('theme')
    if (saved) {
      try {
        const data = JSON.parse(saved)
        if (data.mode) mode.value = data.mode
        if (data.sidebarTheme) sidebarTheme.value = data.sidebarTheme
        if (data.preset) preset.value = data.preset
        if (data.customPrimary) customPrimary.value = data.customPrimary
      } catch { /* ignore */ }
    }

    applyTheme()

    // 监听系统主题变化（auto 模式）
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
      if (mode.value === 'auto') applyTheme()
    })
  }

  function save() {
    localStorage.setItem('theme', JSON.stringify({
      mode: mode.value,
      sidebarTheme: sidebarTheme.value,
      preset: preset.value,
      customPrimary: customPrimary.value,
    }))
    applyTheme()
  }

  watch([mode, sidebarTheme, preset, customPrimary], save)

  return { mode, sidebarTheme, preset, customPrimary, effectivePrimary, init, applyTheme, save }
})

function lightenColor(hex: string, amount: number): string {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  const nr = Math.round(r + (255 - r) * amount)
  const ng = Math.round(g + (255 - g) * amount)
  const nb = Math.round(b + (255 - b) * amount)
  return `#${nr.toString(16).padStart(2, '0')}${ng.toString(16).padStart(2, '0')}${nb.toString(16).padStart(2, '0')}`
}

function darkenColor(hex: string, amount: number): string {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  const nr = Math.round(r * (1 - amount))
  const ng = Math.round(g * (1 - amount))
  const nb = Math.round(b * (1 - amount))
  return `#${nr.toString(16).padStart(2, '0')}${ng.toString(16).padStart(2, '0')}${nb.toString(16).padStart(2, '0')}`
}
