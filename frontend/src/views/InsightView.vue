<template>
  <div>
    <div class="page-header">
      <h3>分析洞察</h3>
      <div class="flex items-center gap-12">
        <el-badge :value="unreadCount" :hidden="unreadCount === 0">
          <el-button @click="showUnreadOnly = !showUnreadOnly; loadInsights()">
            {{ showUnreadOnly ? '显示全部' : '只看未读' }}
          </el-button>
        </el-badge>
        <el-button @click="handleMarkAllRead" :disabled="unreadCount === 0">全部已读</el-button>
        <el-button type="primary" :loading="analyzing" @click="handleAnalyze">
          <el-icon><MagicStick /></el-icon> 开始分析
        </el-button>
      </div>
    </div>

    <el-row :gutter="16" class="mb-16">
      <el-col :span="6" v-for="stat in typeStats" :key="stat.type">
        <el-card shadow="hover" class="cursor-pointer" :class="{ 'active-card': filterType === stat.type }"
          @click="filterType = filterType === stat.type ? '' : stat.type; loadInsights()">
          <div class="stat-card">
            <div class="stat-label">{{ stat.label }}</div>
            <div class="stat-value">{{ stat.count }}</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <div v-if="loading" class="text-center p-20">
      <el-icon class="is-loading" :size="24"><Loading /></el-icon>
      <p class="text-muted mt-8">加载中...</p>
    </div>

    <div v-else-if="insights.length === 0" class="text-center text-muted" style="padding: 60px;">
      <el-icon :size="48"><CircleCheck /></el-icon>
      <p class="mt-12">暂无洞察，点击"开始分析"让系统检查你的消费模式</p>
    </div>

    <div v-else>
      <el-card v-for="ins in insights" :key="ins.id"
        :class="['mb-12', !ins.is_read ? 'unread-card' : '']"
        @click="handleMarkRead(ins)">
        <div class="flex items-start gap-12">
          <div class="insight-icon">{{ typeIcons[ins.type] || '📊' }}</div>
          <div class="flex-1">
            <div class="flex items-center gap-8 mb-4">
              <span class="font-bold">{{ ins.title }}</span>
              <el-tag :type="typeColors[ins.type]" size="small">{{ typeLabels[ins.type] || ins.type }}</el-tag>
              <span v-if="!ins.is_read" class="unread-dot"></span>
            </div>
            <div class="text-regular mb-4">{{ ins.content }}</div>
            <div class="text-sm text-muted">{{ formatTime(ins.created_at) }}</div>
            <!-- 数据详情 -->
            <div v-if="ins.data?.merchants" class="mt-8">
              <el-table :data="ins.data.merchants" size="small" stripe>
                <el-table-column type="index" width="40" />
                <el-table-column prop="merchant" label="商户" />
                <el-table-column label="金额" align="right">
                  <template #default="{ row }">{{ formatMoney(row.total) }}</template>
                </el-table-column>
                <el-table-column prop="count" label="笔数" width="60" align="right" />
              </el-table>
            </div>
          </div>
        </div>
      </el-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { MagicStick, Loading, CircleCheck } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import api from '@/api'

interface Insight {
  id: number
  type: string
  title: string
  content: string
  data: Record<string, unknown> | null
  is_read: boolean
  created_at: string
}

const loading = ref(false)
const analyzing = ref(false)
const insights = ref<Insight[]>([])
const unreadCount = ref(0)
const showUnreadOnly = ref(false)
const filterType = ref('')

const typeLabels: Record<string, string> = {
  trend_alert: '趋势变化',
  category_spike: '分类异常',
  merchant_rank: '商户排行',
  savings_tip: '储蓄建议',
}
const typeColors: Record<string, string> = {
  trend_alert: 'warning',
  category_spike: 'danger',
  merchant_rank: '',
  savings_tip: 'success',
}
const typeIcons: Record<string, string> = {
  trend_alert: '📈',
  category_spike: '⚠️',
  merchant_rank: '🏆',
  savings_tip: '💡',
}

const typeStats = ref([
  { type: 'trend_alert', label: '趋势变化', count: 0 },
  { type: 'category_spike', label: '分类异常', count: 0 },
  { type: 'merchant_rank', label: '商户排行', count: 0 },
  { type: 'savings_tip', label: '储蓄建议', count: 0 },
])

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }
function formatTime(t: string) {
  return new Date(t).toLocaleString('zh-CN', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

async function loadInsights() {
  loading.value = true
  try {
    const params: Record<string, unknown> = { limit: 50 }
    if (showUnreadOnly.value) params.is_read = false
    if (filterType.value) params.type = filterType.value
    const res = await api.get('/insights', { params })
    insights.value = res.data

    // 更新统计
    const allRes = await api.get('/insights', { params: { limit: 200 } })
    for (const stat of typeStats.value) {
      stat.count = allRes.data.filter((i: Insight) => i.type === stat.type).length
    }

    const unreadRes = await api.get('/insights/unread-count')
    unreadCount.value = unreadRes.data.count
  } catch { /* ignore */ }
  finally { loading.value = false }
}

async function handleAnalyze() {
  analyzing.value = true
  try {
    const res = await api.post('/insights/analyze')
    ElMessage.success(res.data.message)
    await loadInsights()
  } catch { ElMessage.error('分析失败') }
  finally { analyzing.value = false }
}

async function handleMarkRead(ins: Insight) {
  if (ins.is_read) return
  try {
    await api.put(`/insights/${ins.id}/read`)
    ins.is_read = true
    unreadCount.value = Math.max(0, unreadCount.value - 1)
  } catch { /* ignore */ }
}

async function handleMarkAllRead() {
  try {
    await api.put('/insights/read-all')
    insights.value.forEach(i => i.is_read = true)
    unreadCount.value = 0
    ElMessage.success('全部已读')
  } catch { ElMessage.error('操作失败') }
}

onMounted(loadInsights)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 12px; }
.page-header h3 { margin: 0; }
.active-card { border-color: var(--color-primary); }
.unread-card { border-left: 3px solid var(--color-primary); }
.unread-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--color-primary); display: inline-block; }
.insight-icon { font-size: 24px; flex-shrink: 0; }
</style>
