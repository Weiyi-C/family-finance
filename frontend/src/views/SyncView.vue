<template>
  <div>
    <div class="page-header">
      <h3>数据同步</h3>
      <div>
        <el-tag type="info">设备ID: {{ clientId }}</el-tag>
        <el-tag type="success" style="margin-left: 8px;">序列号: {{ currentSeq }}</el-tag>
      </div>
    </div>

    <el-row :gutter="16">
      <el-col :span="12">
        <el-card>
          <template #header><span>拉取变更</span></template>
          <el-form :inline="true" size="small">
            <el-form-item label="起始序列"><el-input-number v-model="pullFrom" :min="0" /></el-form-item>
            <el-form-item><el-button type="primary" @click="handlePull" :loading="pulling">拉取</el-button></el-form-item>
          </el-form>
          <el-table :data="pulledChanges" stripe size="small" style="margin-top: 12px;" max-height="400">
            <el-table-column prop="seq" label="序列" width="60" />
            <el-table-column prop="table_name" label="表" width="120" />
            <el-table-column prop="operation" label="操作" width="70">
              <template #default="{ row }">
                <el-tag :type="row.operation === 'INSERT' ? 'success' : row.operation === 'DELETE' ? 'danger' : 'warning'" size="small">{{ row.operation }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="record_id" label="记录ID" width="80" />
          </el-table>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header><span>推送变更</span></template>
          <el-form label-width="80px" size="small">
            <el-form-item label="表名"><el-input v-model="pushForm.table_name" placeholder="transactions" /></el-form-item>
            <el-form-item label="记录ID"><el-input-number v-model="pushForm.record_id" :min="1" /></el-form-item>
            <el-form-item label="操作">
              <el-select v-model="pushForm.operation" style="width: 100%;">
                <el-option label="INSERT" value="INSERT" /><el-option label="UPDATE" value="UPDATE" /><el-option label="DELETE" value="DELETE" />
              </el-select>
            </el-form-item>
            <el-form-item label="数据(JSON)"><el-input v-model="pushForm.dataStr" type="textarea" :rows="3" placeholder="{}" /></el-form-item>
            <el-form-item><el-button type="primary" @click="handlePush" :loading="pushing">推送</el-button></el-form-item>
          </el-form>
          <div v-if="pushResult" style="margin-top: 12px;">
            <el-tag type="success">已应用 {{ pushResult.applied }} 条，当前序列 {{ pushResult.current_seq }}</el-tag>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { syncPull, syncPush } from '@/api/sync'
import type { SyncChange } from '@/api/sync'

const clientId = ref(`web-${Date.now()}`)
const currentSeq = ref(0)
const pullFrom = ref(0)
const pulling = ref(false)
const pushing = ref(false)
const pulledChanges = ref<SyncChange[]>([])
const pushResult = ref<{ applied: number; current_seq: number } | null>(null)
const pushForm = reactive({ table_name: 'transactions', record_id: 1, operation: 'UPDATE', dataStr: '{}' })

async function handlePull() {
  pulling.value = true
  try {
    const res = await syncPull(clientId.value, pullFrom.value)
    pulledChanges.value = res.data.changes; currentSeq.value = res.data.current_seq
    ElMessage.success(`拉取 ${res.data.changes.length} 条变更`)
  } catch { ElMessage.error('拉取失败') } finally { pulling.value = false }
}

async function handlePush() {
  let changeData: Record<string, unknown>
  try { changeData = JSON.parse(pushForm.dataStr) } catch { ElMessage.error('JSON格式错误'); return }
  pushing.value = true
  try {
    const res = await syncPush(clientId.value, [{
      table_name: pushForm.table_name, record_id: pushForm.record_id,
      operation: pushForm.operation, version: 1, change_data: changeData,
    }])
    pushResult.value = res.data; currentSeq.value = res.data.current_seq; ElMessage.success('推送成功')
  } catch { ElMessage.error('推送失败') } finally { pushing.value = false }
}

onMounted(() => { handlePull() })
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
