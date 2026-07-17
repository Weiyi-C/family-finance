<template>
  <div>
    <!-- 时间范围选择器 -->
    <el-card style="margin-bottom: 16px;">
      <div style="display: flex; align-items: center; gap: 16px; flex-wrap: wrap;">
        <el-radio-group v-model="period" @change="onPeriodChange" size="small">
          <el-radio-button value="this_week">本周</el-radio-button>
          <el-radio-button value="this_month">本月</el-radio-button>
          <el-radio-button value="last_month">上月</el-radio-button>
          <el-radio-button value="this_year">今年</el-radio-button>
          <el-radio-button value="last_year">去年</el-radio-button>
          <el-radio-button value="custom">自定义</el-radio-button>
        </el-radio-group>
        <el-date-picker
          v-if="period === 'custom'"
          v-model="customRange"
          type="daterange"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          value-format="YYYY-MM-DD"
          @change="loadData"
          style="width: 260px;"
        />
        <span style="color: #909399; font-size: 13px;">{{ periodLabel }}</span>
      </div>
    </el-card>

    <!-- 概览卡片 -->
    <el-row :gutter="16" class="summary-cards">
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="summary-item">
            <div class="summary-label">收入</div>
            <div class="summary-value income">{{ formatMoney(summary.total_income) }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="summary-item">
            <div class="summary-label">支出</div>
            <div class="summary-value expense">{{ formatMoney(summary.total_expense) }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="summary-item">
            <div class="summary-label">净收支</div>
            <div class="summary-value" :class="summary.net >= 0 ? 'income' : 'expense'">
              {{ formatMoney(summary.net) }}
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="summary-item">
            <div class="summary-label">交易笔数</div>
            <div class="summary-value">{{ summary.count }}</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 图表 -->
    <el-row :gutter="16" style="margin-top: 16px;">
      <el-col :span="12">
        <el-card>
          <template #header><span>趋势</span></template>
          <div ref="trendChartRef" style="height: 300px;"></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header><span>支出分类占比</span></template>
          <div ref="categoryChartRef" style="height: 300px;"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 最近交易 -->
    <el-card style="margin-top: 16px;">
      <template #header><span>最近交易</span></template>
      <el-table :data="recentTxns" stripe>
        <el-table-column prop="transaction_time" label="时间" width="170">
          <template #default="{ row }">{{ formatTime(row.transaction_time) }}</template>
        </el-table-column>
        <el-table-column prop="type" label="类型" width="70">
          <template #default="{ row }">
            <el-tag :type="typeTag[row.type]" size="small">{{ typeMap[row.type] }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="merchant_name" label="商户" />
        <el-table-column prop="description" label="备注" />
        <el-table-column prop="amount" label="金额" align="right" width="120">
          <template #default="{ row }">
            <span :class="row.type === 'expense' ? 'text-expense' : 'text-income'">
              {{ row.type === 'expense' ? '-' : '+' }}{{ formatMoney(row.amount) }}
            </span>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import * as echarts from 'echarts'
import { getSummary, getByCategory, getByDay } from '@/api/stats'
import { getTransactions } from '@/api/transactions'
import type { StatsSummary, CategoryStats, DailyStats, Transaction } from '@/types'

const trendChartRef = ref<HTMLElement>()
const categoryChartRef = ref<HTMLElement>()

const period = ref('this_month')
const customRange = ref<[string, string] | null>(null)

const summary = reactive<StatsSummary>({
  total_income: 0, total_expense: 0, net: 0, count: 0,
})
const categoryData = ref<CategoryStats[]>([])
const dailyData = ref<DailyStats[]>([])
const recentTxns = ref<Transaction[]>([])

const typeMap: Record<string, string> = { expense: '支出', income: '收入', transfer: '转账' }
const typeTag: Record<string, string> = { expense: 'danger', income: 'success', transfer: 'info' }

const periodLabel = computed(() => {
  const { start, end } = getDateRange()
  return `${start} 至 ${end}`
})

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }
function formatTime(t: string) { return t ? new Date(t).toLocaleString('zh-CN') : '' }

function formatDate(date: Date): string {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

function getDateRange(): { start: string; end: string } {
  const now = new Date()
  const y = now.getFullYear()
  const m = now.getMonth()
  const d = now.getDate()
  const dayOfWeek = now.getDay() || 7 // 周日为7

  switch (period.value) {
    case 'this_week': {
      const monday = new Date(now)
      monday.setDate(d - dayOfWeek + 1)
      return { start: formatDate(monday), end: formatDate(now) }
    }
    case 'this_month': {
      const start = `${y}-${String(m + 1).padStart(2, '0')}-01`
      return { start, end: formatDate(now) }
    }
    case 'last_month': {
      const lastMonth = new Date(y, m - 1, 1)
      const lastMonthEnd = new Date(y, m, 0)
      return {
        start: formatDate(lastMonth),
        end: formatDate(lastMonthEnd),
      }
    }
    case 'this_year': {
      return { start: `${y}-01-01`, end: formatDate(now) }
    }
    case 'last_year': {
      return { start: `${y - 1}-01-01`, end: `${y - 1}-12-31` }
    }
    case 'custom': {
      if (customRange.value) {
        return { start: customRange.value[0], end: customRange.value[1] }
      }
      return { start: `${y}-${String(m + 1).padStart(2, '0')}-01`, end: formatDate(now) }
    }
    default:
      return { start: `${y}-01-01`, end: formatDate(now) }
  }
}

function onPeriodChange(val: string) {
  console.log('Period changed to:', val)
  if (val !== 'custom') {
    loadData()
  }
}

async function loadData() {
  const { start, end } = getDateRange()
  console.log('Loading data for:', start, 'to', end)

  try {
    const [summaryRes, catRes, dailyRes, txnRes] = await Promise.all([
      getSummary({ start, end }),
      getByCategory({ start, end }),
      getByDay({ start, end }),
      getTransactions({ start_date: start, end_date: end, page_size: 10 }),
    ])

    console.log('Summary:', summaryRes.data)
    Object.assign(summary, summaryRes.data)
    categoryData.value = catRes.data
    dailyData.value = dailyRes.data
    recentTxns.value = txnRes.data.items || txnRes.data

    renderTrendChart(dailyData.value)
    renderCategoryChart(categoryData.value)
  } catch (e) {
    console.error('加载数据失败', e)
  }
}

function renderTrendChart(data: DailyStats[]) {
  if (!trendChartRef.value || !data.length) return
  const chart = echarts.init(trendChartRef.value)
  chart.setOption({
    tooltip: {
      trigger: 'axis',
      formatter: (params: any) => {
        const p = params[0]
        return `${p.name}<br/>${p.marker} 金额: ¥${(p.value / 100).toFixed(2)}<br/>笔数: ${data[p.dataIndex]?.count || 0}`
      }
    },
    xAxis: {
      type: 'category',
      data: data.map((d) => d.date.slice(5)), // MM-DD
      axisLabel: { rotate: data.length > 15 ? 45 : 0 }
    },
    yAxis: {
      type: 'value',
      axisLabel: { formatter: (v: number) => `¥${(v / 100).toFixed(0)}` }
    },
    series: [{
      type: 'line',
      data: data.map((d) => d.total),
      smooth: true,
      areaStyle: { opacity: 0.3 },
      itemStyle: { color: '#409eff' },
    }],
    grid: { left: 60, right: 20, top: 30, bottom: data.length > 15 ? 60 : 30 },
  })
}

function renderCategoryChart(data: CategoryStats[]) {
  if (!categoryChartRef.value || !data.length) return
  const chart = echarts.init(categoryChartRef.value)
  chart.setOption({
    tooltip: {
      trigger: 'item',
      formatter: (params: any) => `${params.name}: ¥${params.value.toFixed(2)} (${params.percent}%)`
    },
    series: [{
      type: 'pie',
      radius: ['40%', '70%'],
      data: data.map((d) => ({ name: `分类${d.category_id}`, value: d.total / 100 })),
      label: { formatter: '{b}: {d}%' },
    }],
  })
}

onMounted(loadData)
</script>

<style scoped>
.summary-cards .summary-item { text-align: center; }
.summary-label { font-size: 14px; color: #909399; margin-bottom: 8px; }
.summary-value { font-size: 24px; font-weight: 600; }
.income { color: #67c23a; }
.expense { color: #f56c6c; }
.text-expense { color: #f56c6c; }
.text-income { color: #67c23a; }
</style>
