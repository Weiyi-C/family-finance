<template>
  <div>
    <div class="page-header">
      <h3>AI 助手</h3>
      <el-button type="primary" :loading="analyzing" @click="handleAnalyze">
        <el-icon><MagicStick /></el-icon> 开始分析
      </el-button>
    </div>

    <el-alert v-if="!aiEnabled" title="AI 未配置" type="warning" :closable="false" class="mb-16">
      请先在设置中配置 AI 服务。
      <router-link to="/settings">前往设置</router-link>
    </el-alert>

    <!-- 摘要卡片 -->
    <el-row :gutter="16" class="mb-16">
      <el-col :span="8">
        <el-card shadow="hover">
          <div class="stat-card">
            <div class="stat-value">{{ pendingCount }}</div>
            <div class="stat-label">待处理建议</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover">
          <div class="stat-card">
            <div class="stat-value">{{ suggestions.length }}</div>
            <div class="stat-label">总建议数</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover">
          <div class="stat-card">
            <div class="stat-value">{{ acceptedCount }}</div>
            <div class="stat-label">已采纳</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 筛选标签 -->
    <div style="margin-bottom: 16px; display: flex; gap: 12px; align-items: center;">
      <el-radio-group v-model="filterType" @change="loadSuggestions">
        <el-radio-button value="">全部</el-radio-button>
        <el-radio-button value="tag">标签建议</el-radio-button>
        <el-radio-button value="duplicate">重复检测</el-radio-button>
        <el-radio-button value="periodic">周期识别</el-radio-button>
        <el-radio-button value="category">分类建议</el-radio-button>
      </el-radio-group>
      <el-checkbox v-model="showResolved" @change="loadSuggestions">已处理</el-checkbox>
      <div class="flex-1"></div>
      <el-button
        v-if="selectedIds.length > 0"
        type="success"
        size="small"
        @click="handleBatchAction('accept')"
      >批量接受 ({{ selectedIds.length }})</el-button>
      <el-button
        v-if="selectedIds.length > 0"
        type="danger"
        size="small"
        plain
        @click="handleBatchAction('reject')"
      >批量拒绝</el-button>
    </div>

    <!-- 建议列表 -->
    <div v-if="loading" style="text-align: center; padding: 40px;">
      <el-icon class="is-loading" :size="24"><Loading /></el-icon>
      <p class="text-muted mt-8">加载中...</p>
    </div>

    <div v-else-if="filteredSuggestions.length === 0" class="text-center text-muted" style="padding: 60px;">
      <el-icon :size="48"><CircleCheck /></el-icon>
      <p class="mt-12">暂无建议，点击"开始分析"让 AI 检查你的交易</p>
    </div>

    <div v-else>
      <el-card
        v-for="s in filteredSuggestions"
        :key="s.id"
        :class="['suggestion-card', `type-${s.type}`, `status-${s.status}`]"
        class="mb-12"
      >
        <div class="flex items-start gap-12">
          <el-checkbox
            v-if="s.status === 'pending'"
            v-model="s._selected"
            @change="updateSelection"
          />
          <div class="flex-1">
            <!-- 标签建议 -->
            <template v-if="s.type === 'tag'">
              <div class="suggestion-header">
                <el-tag type="primary" size="small">标签建议</el-tag>
                <span class="suggestion-time">{{ formatTime(s.created_at) }}</span>
              </div>
              <div class="suggestion-body">
                <p>建议为交易添加标签：</p>
                <div style="margin: 8px 0;">
                  <el-tag v-for="tag in (s.suggestion.tags as string[])" :key="tag" style="margin-right: 6px;">{{ tag }}</el-tag>
                </div>
                <p v-if="s.reason" class="reason">{{ s.reason }}</p>
              </div>
            </template>

            <!-- 重复检测 -->
            <template v-else-if="s.type === 'duplicate'">
              <div class="suggestion-header">
                <el-tag type="warning" size="small">重复检测</el-tag>
                <span class="suggestion-time">{{ formatTime(s.created_at) }}</span>
              </div>
              <div class="suggestion-body">
                <p>检测到疑似重复交易（{{ (s.suggestion.duplicate_group as number[])?.length || 0 }}条）</p>
                <p v-if="s.reason" class="reason">{{ s.reason }}</p>
              </div>
            </template>

            <!-- 周期识别 -->
            <template v-else-if="s.type === 'periodic'">
              <div class="suggestion-header">
                <el-tag type="success" size="small">周期识别</el-tag>
                <span class="suggestion-time">{{ formatTime(s.created_at) }}</span>
              </div>
              <div class="suggestion-body">
                <p>识别到周期性消费：<strong>{{ s.suggestion.suggested_name || s.suggestion.merchant }}</strong></p>
                <p>周期：{{ intervalLabel(s.suggestion.interval as string) }}</p>
                <p v-if="s.reason" class="reason">{{ s.reason }}</p>
              </div>
            </template>

            <!-- 分类建议 -->
            <template v-else-if="s.type === 'category'">
              <div class="suggestion-header">
                <el-tag type="info" size="small">分类建议</el-tag>
                <span class="suggestion-time">{{ formatTime(s.created_at) }}</span>
              </div>
              <div class="suggestion-body">
                <p>建议分类：<strong>{{ s.suggestion.category_name }}</strong>
                  <span v-if="s.suggestion.confidence" class="text-muted ml-8">
                    置信度 {{ Math.round((s.suggestion.confidence as number) * 100) }}%
                  </span>
                </p>
                <p v-if="s.reason" class="reason">{{ s.reason }}</p>
              </div>
            </template>

            <!-- 状态标签 -->
            <div v-if="s.status !== 'pending'" style="margin-top: 8px;">
              <el-tag :type="s.status === 'accepted' ? 'success' : 'danger'" size="small">
                {{ s.status === 'accepted' ? '已采纳' : '已拒绝' }}
              </el-tag>
            </div>
          </div>

          <!-- 操作按钮 -->
          <div v-if="s.status === 'pending'" class="flex gap-8 flex-shrink-0">
            <el-button type="success" size="small" @click="handleAccept(s)">接受</el-button>
            <el-button type="danger" size="small" plain @click="handleReject(s)">拒绝</el-button>
          </div>
        </div>
      </el-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { MagicStick, Loading, CircleCheck } from '@element-plus/icons-vue'
import {
  triggerAnalysis, getAISuggestions, acceptSuggestion, rejectSuggestion,
  batchActionSuggestions, getAISettings,
  type AISuggestion,
} from '@/api/ai'

interface SuggestionWithSelect extends AISuggestion {
  _selected?: boolean
}

const loading = ref(false)
const analyzing = ref(false)
const aiEnabled = ref(false)
const suggestions = ref<SuggestionWithSelect[]>([])
const pendingCount = ref(0)
const filterType = ref('')
const showResolved = ref(false)
const selectedIds = ref<number[]>([])

const acceptedCount = computed(() => suggestions.value.filter(s => s.status === 'accepted').length)

const filteredSuggestions = computed(() => {
  let list = suggestions.value
  if (filterType.value) list = list.filter(s => s.type === filterType.value)
  if (!showResolved.value) list = list.filter(s => s.status === 'pending')
  return list
})

function intervalLabel(interval: string): string {
  const map: Record<string, string> = { monthly: '每月', weekly: '每周', yearly: '每年', daily: '每天' }
  return map[interval] || interval
}

function formatTime(t: string | null): string {
  if (!t) return ''
  return new Date(t).toLocaleString('zh-CN', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function updateSelection() {
  selectedIds.value = suggestions.value.filter(s => s._selected && s.status === 'pending').map(s => s.id)
}

async function loadSuggestions() {
  loading.value = true
  try {
    const params: Record<string, string> = {}
    if (filterType.value) params.type = filterType.value
    if (showResolved.value) params.status = 'all'
    const res = await getAISuggestions(params)
    suggestions.value = res.data.suggestions.map(s => ({ ...s, _selected: false }))
    pendingCount.value = res.data.pending_count
  } catch {
    // ignore
  } finally {
    loading.value = false
  }
}

async function handleAnalyze() {
  analyzing.value = true
  try {
    const res = await triggerAnalysis()
    ElMessage.success(res.data.message)
    await loadSuggestions()
  } catch {
    ElMessage.error('分析失败')
  } finally {
    analyzing.value = false
  }
}

async function handleAccept(s: SuggestionWithSelect) {
  try {
    await acceptSuggestion(s.id)
    s.status = 'accepted'
    ElMessage.success('已采纳')
    pendingCount.value = Math.max(0, pendingCount.value - 1)
  } catch {
    ElMessage.error('操作失败')
  }
}

async function handleReject(s: SuggestionWithSelect) {
  try {
    await rejectSuggestion(s.id)
    s.status = 'rejected'
    ElMessage.success('已拒绝')
    pendingCount.value = Math.max(0, pendingCount.value - 1)
  } catch {
    ElMessage.error('操作失败')
  }
}

async function handleBatchAction(action: 'accept' | 'reject') {
  try {
    await batchActionSuggestions(selectedIds.value, action)
    ElMessage.success(`已${action === 'accept' ? '接受' : '拒绝'} ${selectedIds.value.length} 条建议`)
    selectedIds.value = []
    await loadSuggestions()
  } catch {
    ElMessage.error('操作失败')
  }
}

onMounted(async () => {
  try {
    const res = await getAISettings()
    aiEnabled.value = res.data.enabled
  } catch {
    aiEnabled.value = false
  }
  await loadSuggestions()
})
</script>

<style scoped>
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}
.stat-card {
  text-align: center;
  padding: 8px 0;
}
.stat-value {
  font-size: 28px;
  font-weight: 700;
  color: var(--color-text-primary);
}
.stat-label {
  font-size: 13px;
  color: var(--color-text-secondary);
  margin-top: 4px;
}
.suggestion-card {
  transition: all 0.2s;
}
.suggestion-card.status-pending {
  border-left: 3px solid var(--color-primary);
}
.suggestion-card.status-accepted {
  opacity: 0.6;
}
.suggestion-card.status-rejected {
  opacity: 0.4;
}
.suggestion-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}
.suggestion-time {
  font-size: 12px;
  color: var(--color-text-secondary);
}
.suggestion-body {
  font-size: 14px;
  color: var(--color-text-primary);
}
.reason {
  font-size: 12px;
  color: var(--color-text-secondary);
  margin-top: 4px;
}
</style>
