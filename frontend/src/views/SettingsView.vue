<template>
  <div>
    <div class="page-header">
      <h3>设置</h3>
    </div>

    <el-card>
      <el-form :model="settings" label-width="120px" v-loading="loading">
        <el-form-item label="昵称">
          <el-input v-model="nickname" placeholder="请输入昵称" style="width: 200px;" />
          <el-button type="primary" class="ml-8" :loading="savingNickname" @click="handleSaveNickname">保存</el-button>
        </el-form-item>
        <el-form-item label="手机号">
          <span>{{ auth.user?.phone || '-' }}</span>
        </el-form-item>
        <el-divider>偏好设置</el-divider>
        <el-form-item label="默认货币">
          <el-select v-model="settings.default_currency" style="width: 200px;">
            <el-option label="人民币 (CNY)" value="CNY" /><el-option label="美元 (USD)" value="USD" /><el-option label="欧元 (EUR)" value="EUR" />
          </el-select>
        </el-form-item>
        <el-form-item label="每月起始日">
          <el-input-number v-model="settings.month_start_day" :min="1" :max="28" />
        </el-form-item>
        <el-divider>外观设置</el-divider>
        <el-form-item label="主题模式">
          <el-radio-group v-model="themeStore.mode">
            <el-radio-button value="light">浅色</el-radio-button>
            <el-radio-button value="dark">深色</el-radio-button>
            <el-radio-button value="auto">跟随系统</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="侧边栏">
          <el-radio-group v-model="themeStore.sidebarTheme">
            <el-radio-button value="dark">深色</el-radio-button>
            <el-radio-button value="light">浅色</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="主题色">
          <div class="theme-color-row">
            <div
              v-for="t in themePresets"
              :key="t.name"
              class="color-dot"
              :class="{ active: themeStore.preset === t.name && !themeStore.customPrimary }"
              :style="{ backgroundColor: t.primary }"
              :title="t.label"
              @click="selectPreset(t.name)"
            />
            <el-color-picker
              v-model="themeStore.customPrimary"
              size="small"
              show-alpha={false}
              @change="onCustomColorChange"
            />
          </div>
        </el-form-item>

        <el-divider>通知设置</el-divider>
        <el-form-item label="预算预警">
          <el-switch v-model="settings.notify_budget_alert" />
        </el-form-item>
        <el-form-item label="周期交易提醒">
          <el-switch v-model="settings.notify_recurring" />
        </el-form-item>
        <el-form-item label="同步通知">
          <el-switch v-model="settings.notify_sync" />
        </el-form-item>

        <el-divider>同步设置</el-divider>
        <el-form-item label="自动同步">
          <el-switch v-model="settings.auto_sync" />
        </el-form-item>
        <el-form-item label="仅WiFi同步">
          <el-switch v-model="settings.sync_on_wifi_only" />
        </el-form-item>

        <el-divider>AI 智能分类</el-divider>
        <el-form-item label="启用 AI">
          <el-switch v-model="aiSettings.enabled" />
        </el-form-item>
        <template v-if="aiSettings.enabled">
          <el-form-item label="AI 提供商">
            <el-select v-model="aiSettings.provider" class="w-full" @change="onProviderChange">
              <el-option v-for="p in providers" :key="p.id" :label="p.name" :value="p.id" />
            </el-select>
          </el-form-item>
          <el-form-item label="API Key">
            <el-input v-model="aiSettings.api_key" placeholder="输入 API Key" show-password />
            <div v-if="aiSettings.api_key_masked" class="text-sm text-muted mt-4">
              当前: {{ aiSettings.api_key_masked }}
            </div>
          </el-form-item>
          <el-form-item label="API 地址" v-if="aiSettings.provider === 'custom'">
            <el-input v-model="aiSettings.base_url" placeholder="https://api.example.com/v1" />
          </el-form-item>
          <el-form-item label="模型">
            <el-select v-model="aiSettings.model" class="w-full" filterable allow-create>
              <el-option v-for="m in currentModels" :key="m" :label="m" :value="m" />
            </el-select>
          </el-form-item>
          <el-form-item>
            <el-button @click="testConnection" :loading="testing">测试连接</el-button>
          </el-form-item>
        </template>

        <el-form-item>
          <el-button type="primary" :loading="saving" @click="handleSave">保存设置</el-button>
        </el-form-item>

        <el-divider>修改密码</el-divider>
        <el-form-item label="原密码">
          <el-input v-model="pwdForm.old_password" type="password" placeholder="输入原密码" show-password style="width: 280px;" />
        </el-form-item>
        <el-form-item label="新密码">
          <el-input v-model="pwdForm.new_password" type="password" placeholder="至少6位" show-password style="width: 280px;" />
        </el-form-item>
        <el-form-item label="确认密码">
          <el-input v-model="pwdForm.confirm_password" type="password" placeholder="再次输入新密码" show-password style="width: 280px;" />
        </el-form-item>
        <el-form-item>
          <el-button type="warning" :loading="changingPwd" @click="handleChangePassword">修改密码</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getSettings, updateSettings } from '@/api/settings'
import { getAIProviders, getAISettings, updateAISettings, testAIConnection } from '@/api/ai'
import { updateMe, changePassword } from '@/api/users'
import { useAuthStore } from '@/stores/auth'
import { useThemeStore, themePresets } from '@/stores/theme'
import type { UserSettings } from '@/types'
import type { AIProvider } from '@/api/ai'

const auth = useAuthStore()
const themeStore = useThemeStore()

function selectPreset(name: string) {
  themeStore.customPrimary = ''
  themeStore.preset = name
}

function onCustomColorChange(color: string | null) {
  if (color) {
    themeStore.customPrimary = color
  }
}

const loading = ref(false)
const saving = ref(false)
const testing = ref(false)
const changingPwd = ref(false)

const nickname = ref('')
const savingNickname = ref(false)

const pwdForm = reactive({ old_password: '', new_password: '', confirm_password: '' })

const settings = reactive<UserSettings>({
  id: 0, user_id: 0, default_currency: 'CNY', month_start_day: 1, theme: 'light', language: 'zh-CN',
  date_format: 'YYYY-MM-DD', number_format: '1,234.56', default_book_id: null, quick_entry_mode: 'disabled',
  confirm_before_save: true, notify_budget_alert: true, notify_recurring: true, notify_sync: true,
  quiet_hours_start: null, quiet_hours_end: null, auto_sync: true, sync_on_wifi_only: true, settings_json: null,
})

// AI 设置
const providers = ref<AIProvider[]>([])
const aiSettings = reactive({
  provider: '',
  api_key: '',
  api_key_masked: '',
  base_url: '',
  model: '',
  enabled: false,
})

// 当前提供商的模型列表
const currentModels = computed(() => {
  const provider = providers.value.find((p) => p.id === aiSettings.provider)
  return provider?.models || []
})

function onProviderChange(providerId: string) {
  const provider = providers.value.find((p) => p.id === providerId)
  if (provider) {
    aiSettings.model = provider.default_model
    if (providerId !== 'custom') {
      aiSettings.base_url = ''
    }
  }
}

async function load() {
  loading.value = true
  try {
    nickname.value = auth.user?.nickname || ''
    const [settingsRes, providersRes, aiRes] = await Promise.all([
      getSettings(),
      getAIProviders(),
      getAISettings(),
    ])
    Object.assign(settings, settingsRes.data)
    providers.value = providersRes.data
    Object.assign(aiSettings, aiRes.data)
  } finally { loading.value = false }
}

async function handleSave() {
  saving.value = true
  try {
    // 保存普通设置
    const settingsRes = await updateSettings({
      default_currency: settings.default_currency, month_start_day: settings.month_start_day,
      theme: settings.theme, language: settings.language, quick_entry_mode: settings.quick_entry_mode,
      confirm_before_save: settings.confirm_before_save, notify_budget_alert: settings.notify_budget_alert,
      notify_recurring: settings.notify_recurring, notify_sync: settings.notify_sync,
      auto_sync: settings.auto_sync, sync_on_wifi_only: settings.sync_on_wifi_only,
    })
    Object.assign(settings, settingsRes.data)

    // 保存 AI 设置
    if (aiSettings.enabled && aiSettings.provider && aiSettings.api_key) {
      await updateAISettings({
        provider: aiSettings.provider,
        api_key: aiSettings.api_key,
        base_url: aiSettings.base_url,
        model: aiSettings.model,
        enabled: aiSettings.enabled,
      })
    } else if (!aiSettings.enabled) {
      // 如果禁用了，可以选择删除配置或只更新 enabled 状态
      if (aiSettings.provider) {
        await updateAISettings({
          provider: aiSettings.provider,
          api_key: aiSettings.api_key || 'disabled',
          enabled: false,
        })
      }
    }

    ElMessage.success('保存成功')
    // 重新加载 AI 设置以获取掩码
    const aiRes = await getAISettings()
    Object.assign(aiSettings, aiRes.data)
  } catch { ElMessage.error('保存失败') }
  finally { saving.value = false }
}

async function handleSaveNickname() {
  if (!nickname.value.trim()) {
    ElMessage.warning('昵称不能为空')
    return
  }
  savingNickname.value = true
  try {
    await updateMe({ nickname: nickname.value.trim() })
    await auth.fetchUser()
    ElMessage.success('昵称已更新')
  } catch (err: any) {
    ElMessage.error(err?.response?.data?.detail || '更新失败')
  } finally {
    savingNickname.value = false
  }
}

async function testConnection() {
  testing.value = true
  try {
    const res = await testAIConnection()
    ElMessage.success(`连接成功: ${res.data.response}`)
  } catch (err: any) {
    ElMessage.error(err?.response?.data?.detail || '连接测试失败')
  } finally { testing.value = false }
}

async function handleChangePassword() {
  if (!pwdForm.old_password || !pwdForm.new_password) {
    ElMessage.warning('请填写原密码和新密码')
    return
  }
  if (pwdForm.new_password.length < 6) {
    ElMessage.warning('新密码至少6位')
    return
  }
  if (pwdForm.new_password !== pwdForm.confirm_password) {
    ElMessage.warning('两次输入的密码不一致')
    return
  }
  changingPwd.value = true
  try {
    await changePassword({ old_password: pwdForm.old_password, new_password: pwdForm.new_password })
    ElMessage.success('密码修改成功')
    pwdForm.old_password = ''
    pwdForm.new_password = ''
    pwdForm.confirm_password = ''
  } catch (err: any) {
    ElMessage.error(err?.response?.data?.detail || '修改失败')
  } finally {
    changingPwd.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.page-header { margin-bottom: 16px; }
.page-header h3 { margin: 0; }

.theme-color-row {
  display: flex;
  align-items: center;
  gap: 10px;
}
.color-dot {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  cursor: pointer;
  border: 2px solid transparent;
  transition: all 0.2s;
  position: relative;
}
.color-dot:hover {
  transform: scale(1.15);
}
.color-dot.active {
  border-color: var(--color-text-primary);
  box-shadow: 0 0 0 2px var(--color-bg-card), 0 0 0 4px var(--color-primary);
}
.color-dot.active::after {
  content: '✓';
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  color: var(--color-bg-card);
  font-size: 14px;
  font-weight: bold;
  text-shadow: 0 1px 2px rgba(0,0,0,0.3);
}
</style>
