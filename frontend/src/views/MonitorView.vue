<template>
  <div>
    <div class="page-header">
      <h3>系统监控</h3>
      <el-button @click="load" :loading="loading">刷新</el-button>
    </div>

    <!-- 摘要卡片 -->
    <el-row :gutter="16" style="margin-bottom: 16px;">
      <el-col :span="8">
        <el-card shadow="hover">
          <div style="text-align: center;">
            <div style="font-size: 13px; color: #909399;">今日错误</div>
            <div style="font-size: 28px; font-weight: 600; color: #f56c6c; margin: 8px 0;">{{ summary.today_errors }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover">
          <div style="text-align: center;">
            <div style="font-size: 13px; color: #909399;">本周慢查询</div>
            <div style="font-size: 28px; font-weight: 600; color: #e6a23c; margin: 8px 0;">{{ summary.week_slow_queries }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover">
          <div style="text-align: center;">
            <div style="font-size: 13px; color: #909399;">服务状态</div>
            <div style="font-size: 28px; font-weight: 600; color: #67c23a; margin: 8px 0;">正常</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16">
      <!-- 最近错误 -->
      <el-col :span="12">
        <el-card>
          <template #header><span>最近错误</span></template>
          <el-table :data="errors" stripe size="small" max-height="400">
            <el-table-column prop="level" label="级别" width="70">
              <template #default="{ row }">
                <el-tag :type="row.level === 'error' ? 'danger' : 'warning'" size="small">{{ row.level }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="endpoint" label="接口" width="150" show-overflow-tooltip />
            <el-table-column prop="error_type" label="异常类型" width="120" show-overflow-tooltip />
            <el-table-column prop="message" label="信息" min-width="200" show-overflow-tooltip />
            <el-table-column prop="created_at" label="时间" width="160">
              <template #default="{ row }">{{ row.created_at ? new Date(row.created_at).toLocaleString('zh-CN') : '-' }}</template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>

      <!-- 慢查询 -->
      <el-col :span="12">
        <el-card>
          <template #header><span>慢查询 (>1s)</span></template>
          <el-table :data="slowQueries" stripe size="small" max-height="400">
            <el-table-column prop="endpoint" label="接口" width="150" show-overflow-tooltip />
            <el-table-column prop="duration_ms" label="耗时" width="80">
              <template #default="{ row }">
                <span :style="{ color: row.duration_ms > 3000 ? '#f56c6c' : '#e6a23c' }">{{ row.duration_ms }}ms</span>
              </template>
            </el-table-column>
            <el-table-column prop="query_text" label="SQL" min-width="200" show-overflow-tooltip />
            <el-table-column prop="created_at" label="时间" width="160">
              <template #default="{ row }">{{ row.created_at ? new Date(row.created_at).toLocaleString('zh-CN') : '-' }}</template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getMonitorSummary, getErrorLogs, getSlowQueries } from '@/api/monitor'
import type { ErrorLog, SlowQuery, MonitorSummary } from '@/api/monitor'

const loading = ref(false)
const summary = reactive<MonitorSummary>({ today_errors: 0, week_slow_queries: 0, recent_errors: [] })
const errors = ref<ErrorLog[]>([])
const slowQueries = ref<SlowQuery[]>([])

async function load() {
  loading.value = true
  try {
    const [summaryRes, errorsRes, slowRes] = await Promise.all([
      getMonitorSummary(),
      getErrorLogs({ limit: 20 }),
      getSlowQueries({ limit: 20 }),
    ])
    Object.assign(summary, summaryRes.data)
    errors.value = errorsRes.data
    slowQueries.value = slowRes.data
  } catch {
    ElMessage.error('加载监控数据失败')
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}
.page-header h3 { margin: 0; }
</style>
