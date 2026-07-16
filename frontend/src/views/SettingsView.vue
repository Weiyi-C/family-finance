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

        <el-form-item>
          <el-button type="primary" :loading="saving" @click="handleSave">保存设置</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getSettings, updateSettings } from '@/api/settings'
import type { UserSettings } from '@/types'

const loading = ref(false)
const saving = ref(false)

const settings = reactive<UserSettings>({
  id: 0, user_id: 0, default_currency: 'CNY', month_start_day: 1, theme: 'light', language: 'zh-CN',
  date_format: 'YYYY-MM-DD', number_format: '1,234.56', default_book_id: null, quick_entry_mode: 'disabled',
  confirm_before_save: true, notify_budget_alert: true, notify_recurring: true, notify_sync: true,
  quiet_hours_start: null, quiet_hours_end: null, auto_sync: true, sync_on_wifi_only: true, settings_json: null,
})

async function load() {
  loading.value = true
  try {
    const res = await getSettings()
    Object.assign(settings, res.data)
  } finally { loading.value = false }
}

async function handleSave() {
  saving.value = true
  try {
    const res = await updateSettings({
      default_currency: settings.default_currency, month_start_day: settings.month_start_day,
      theme: settings.theme, language: settings.language, quick_entry_mode: settings.quick_entry_mode,
      confirm_before_save: settings.confirm_before_save, notify_budget_alert: settings.notify_budget_alert,
      notify_recurring: settings.notify_recurring, notify_sync: settings.notify_sync,
      auto_sync: settings.auto_sync, sync_on_wifi_only: settings.sync_on_wifi_only,
    })
    Object.assign(settings, res.data)
    ElMessage.success('保存成功')
  } catch { ElMessage.error('保存失败') }
  finally { saving.value = false }
}

onMounted(load)
</script>

<style scoped>
.page-header { margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
