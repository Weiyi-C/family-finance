<template>
  <div>
    <div class="page-header">
      <h3>备份管理</h3>
      <el-button type="primary" :loading="backing" @click="handleBackup"><el-icon><Download /></el-icon> 立即备份</el-button>
    </div>

    <el-row :gutter="16">
      <el-col :span="12">
        <el-card>
          <template #header><span>备份配置</span></template>
          <el-button type="primary" size="small" @click="showConfigDialog = true" style="margin-bottom: 12px;">新建配置</el-button>
          <el-table :data="configs" stripe size="small">
            <el-table-column prop="backup_type" label="类型" width="80" />
            <el-table-column prop="schedule" label="计划" />
            <el-table-column prop="target" label="目标" width="80" />
            <el-table-column prop="is_enabled" label="状态" width="70">
              <template #default="{ row }"><el-tag :type="row.is_enabled ? 'success' : 'info'" size="small">{{ row.is_enabled ? '启用' : '停用' }}</el-tag></template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header><span>备份日志</span></template>
          <el-table :data="logs" stripe size="small" v-loading="loading">
            <el-table-column prop="backup_type" label="类型" width="70" />
            <el-table-column label="大小" width="80">
              <template #default="{ row }">{{ row.file_size ? `${(row.file_size / 1024).toFixed(1)}KB` : '-' }}</template>
            </el-table-column>
            <el-table-column prop="status" label="状态" width="70">
              <template #default="{ row }"><el-tag :type="row.status === 'success' ? 'success' : 'danger'" size="small">{{ row.status === 'success' ? '成功' : '失败' }}</el-tag></template>
            </el-table-column>
            <el-table-column label="耗时" width="80">
              <template #default="{ row }">{{ row.duration_ms ? `${row.duration_ms}ms` : '-' }}</template>
            </el-table-column>
            <el-table-column prop="created_at" label="时间" width="160">
              <template #default="{ row }">{{ row.created_at ? new Date(row.created_at).toLocaleString('zh-CN') : '' }}</template>
            </el-table-column>
            <el-table-column label="操作" width="80">
              <template #default="{ row }">
                <el-popconfirm title="确定删除？" @confirm="handleDeleteLog(row.id)">
                  <template #reference><el-button link type="danger" size="small">删除</el-button></template>
                </el-popconfirm>
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
    </el-row>

    <el-dialog v-model="showConfigDialog" title="新建备份配置" width="460px" destroy-on-close>
      <el-form :model="configForm" label-width="80px">
        <el-form-item label="类型">
          <el-select v-model="configForm.backup_type" style="width: 100%;">
            <el-option label="全量" value="full" /><el-option label="增量" value="incremental" />
          </el-select>
        </el-form-item>
        <el-form-item label="计划"><el-input v-model="configForm.schedule" placeholder="如: daily, weekly, 0 2 * * *" /></el-form-item>
        <el-form-item label="目标">
          <el-select v-model="configForm.target" style="width: 100%;">
            <el-option label="本地" value="local" /><el-option label="S3" value="s3" />
          </el-select>
        </el-form-item>
        <el-form-item label="保留天数"><el-input-number v-model="configForm.retention_days" :min="1" :max="365" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showConfigDialog = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleCreateConfig">创建</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Download } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getBackupConfigs, createBackupConfig, triggerBackup, getBackupLogs, deleteBackupLog } from '@/api/backup'
import type { BackupConfig, BackupLog } from '@/api/backup'

const loading = ref(false)
const backing = ref(false)
const saving = ref(false)
const configs = ref<BackupConfig[]>([])
const logs = ref<BackupLog[]>([])
const showConfigDialog = ref(false)
const configForm = reactive({ backup_type: 'full', schedule: 'daily', target: 'local', retention_days: 30 })

async function load() {
  loading.value = true
  try {
    const [cfgRes, logRes] = await Promise.all([getBackupConfigs(), getBackupLogs()])
    configs.value = cfgRes.data; logs.value = logRes.data
  } finally { loading.value = false }
}

async function handleBackup() {
  backing.value = true
  try { await triggerBackup(); ElMessage.success('备份完成'); await load() }
  catch { ElMessage.error('备份失败') } finally { backing.value = false }
}

async function handleCreateConfig() {
  saving.value = true
  try { await createBackupConfig(configForm); ElMessage.success('创建成功'); showConfigDialog.value = false; await load() }
  catch { ElMessage.error('创建失败') } finally { saving.value = false }
}

async function handleDeleteLog(id: number) {
  try { await deleteBackupLog(id); ElMessage.success('已删除'); await load() } catch { ElMessage.error('删除失败') }
}

onMounted(load)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
