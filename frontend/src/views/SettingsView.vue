<template>
  <div>
    <div class="page-header">
      <h3>设置</h3>
    </div>

    <el-card>
      <el-form :model="settings" label-width="120px" v-loading="loading">
        <el-form-item label="默认货币">
          <el-select v-model="settings.default_currency" style="width: 200px;">
            <el-option label="人民币 (CNY)" value="CNY" /><el-option label="美元 (USD)" value="USD" /><el-option label="欧元 (EUR)" value="EUR" />
          </el-select>
        </el-form-item>
        <el-form-item label="每月起始日">
          <el-input-number v-model="settings.month_start_day" :min="1" :max="28" />
        </el-form-item>
        <el-form-item label="主题">
          <el-radio-group v-model="settings.theme">
            <el-radio-button value="light">浅色</el-radio-button>
            <el-radio-button value="dark">深色</el-radio-button>
            <el-radio-button value="auto">跟随系统</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="语言">
          <el-select v-model="settings.language" style="width: 200px;">
            <el-option label="中文" value="zh-CN" /><el-option label="English" value="en" />
          </el-select>
        </el-form-item>
        <el-form-item label="快捷记账">
          <el-switch v-model="settings.quick_entry_mode" active-value="enabled" inactive-value="disabled" />
        </el-form-item>
        <el-form-item label="保存前确认">
          <el-switch v-model="settings.confirm_before_save" />
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
            <el-select v-model="aiSettings.provider" style="width: 100%;" @change="onProviderChange">
              <el-option v-for="p in providers" :key="p.id" :label="p.name" :value="p.id" />
            </el-select>
          </el-form-item>
          <el-form-item label="API Key">
            <el-input v-model="aiSettings.api_key" placeholder="输入 API Key" show-password />
            <div v-if="aiSettings.api_key_masked" style="color: #909399; font-size: 12px; margin-top: 4px;">
              当前: {{ aiSettings.api_key_masked }}
            </div>
          </el-form-item>
          <el-form-item label="API 地址" v-if="aiSettings.provider === 'custom'">
            <el-input v-model="aiSettings.base_url" placeholder="https://api.example.com/v1" />
          </el-form-item>
          <el-form-item label="模型">
            <el-select v-model="aiSettings.model" style="width: 100%;" filterable allow-create>
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
      </el-form>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getSettings, updateSettings } from '@/api/settings'
import { getAIProviders, getAISettings, updateAISettings, testAIConnection } from '@/api/ai'
import type { UserSettings } from '@/types'
import type { AIProvider } from '@/api/ai'

const loading = ref(false)
const saving = ref(false)
const testing = ref(false)

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

async function testConnection() {
  testing.value = true
  try {
    const res = await testAIConnection()
    ElMessage.success(`连接成功: ${res.data.response}`)
  } catch (err: any) {
    ElMessage.error(err?.response?.data?.detail || '连接测试失败')
  } finally { testing.value = false }
}

onMounted(load)
</script>

<style scoped>
.page-header { margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
