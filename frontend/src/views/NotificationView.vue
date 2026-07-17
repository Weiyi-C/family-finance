<template>
  <div>
    <div class="page-header">
      <h3>通知</h3>
      <el-button @click="handleMarkAllRead" :loading="marking">全部已读</el-button>
    </div>
    <el-card>
      <el-table :data="notifications" stripe v-loading="loading">
        <el-table-column prop="title" label="标题" />
        <el-table-column prop="type" label="类型" width="100">
          <template #default="{ row }">
            <el-tag size="small">{{ row.type }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="content" label="内容" show-overflow-tooltip />
        <el-table-column prop="is_read" label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.is_read ? 'info' : 'danger'" size="small">{{ row.is_read ? '已读' : '未读' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="时间" width="170">
          <template #default="{ row }">{{ row.created_at ? new Date(row.created_at).toLocaleString('zh-CN') : '' }}</template>
        </el-table-column>
        <el-table-column label="操作" width="100">
          <template #default="{ row }">
            <el-button v-if="!row.is_read" link type="primary" size="small" @click="handleMarkRead(row.id)">标记已读</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getNotifications, markNotificationRead, markAllNotificationsRead } from '@/api/notifications'
import type { Notification } from '@/api/notifications'

const loading = ref(false)
const marking = ref(false)
const notifications = ref<Notification[]>([])

async function load() {
  loading.value = true
  try { notifications.value = (await getNotifications()).data } finally { loading.value = false }
}

async function handleMarkRead(id: number) {
  try { await markNotificationRead(id); await load() } catch { ElMessage.error('操作失败') }
}

async function handleMarkAllRead() {
  marking.value = true
  try { await markAllNotificationsRead(); ElMessage.success('全部已读'); await load() }
  catch { ElMessage.error('操作失败') } finally { marking.value = false }
}

onMounted(load)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
