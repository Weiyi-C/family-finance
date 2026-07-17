<template>
  <div>
    <el-row :gutter="16" class="summary-cards">
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="summary-item">
            <div class="summary-label">本月收入</div>
            <div class="summary-value income">{{ formatMoney(summary.total_income) }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="summary-item">
            <div class="summary-label">本月支出</div>
            <div class="summary-value expense">{{ formatMoney(summary.total_expense) }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="summary-item">
            <div class="summary-label">本月结余</div>
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

    <el-row :gutter="16" style="margin-top: 16px;">
      <el-col :span="12">
        <el-card>
          <template #header><span>月度趋势</span></template>
          <div ref="monthlyChartRef" style="height: 300px;"></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header><span>支出分类占比</span></template>
          <div ref="categoryChartRef" style="height: 300px;"></div>
        </el-card>
      </el-col>
    </el-row>

    <el-card style="margin-top: 16px;">
      <template #header><span>最近交易</span></template>
      <el-table :data="recentTxns" stripe>
        <el-table-column prop="transaction_time" label="时间" width="180">
          <template #default="{ row }">{{ formatTime(row.transaction_time) }}</template>
        </el-table-column>
        <el-table-column prop="type" label="类型" width="80">
          <template #default="{ row }">
            <el-tag :type="row.type === 'expense' ? 'danger' : row.type === 'income' ? 'success' : 'info'" size="small">
              {{ typeMap[row.type] || row.type }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="category_id" label="分类" />
        <el-table-column prop="merchant_name" label="商户" />
        <el-table-column prop="amount" label="金额" align="right">
          <template #default="{ row }">{{ formatMoney(row.amount) }}</template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import * as echarts from 'echarts'
import { getSummary, getByCategory, getByMonth } from '@/api/stats'
import { getTransactions } from '@/api/transactions'
import type { StatsSummary, CategoryStats, MonthlyStats, Transaction } from '@/types'

const monthlyChartRef = ref<HTMLElement>()
const categoryChartRef = ref<HTMLElement>()

const summary = reactive<StatsSummary>({
  total_income: 0, total_expense: 0, net: 0, count: 0,
})
const categoryData = ref<CategoryStats[]>([])
const monthlyData = ref<MonthlyStats[]>([])
const recentTxns = ref<Transaction[]>([])

const typeMap: Record<string, string> = { expense: '支出', income: '收入', transfer: '转账' }

function formatMoney(val: number) {
  return `¥${(val / 100).toFixed(2)}`
}

function formatTime(t: string) {
  return t ? new Date(t).toLocaleString('zh-CN') : ''
}

function getMonthRange() {
  const now = new Date()
  const y = now.getFullYear()
  const m = now.getMonth()
  const start = `${y}-${String(m + 1).padStart(2, '0')}-01`
  const end = new Date(y, m + 1, 0).toISOString().slice(0, 10)
  return { start, end }
}

function renderMonthlyChart(data: MonthlyStats[]) {
  if (!monthlyChartRef.value) return
  const chart = echarts.init(monthlyChartRef.value)
  chart.setOption({
    tooltip: { trigger: 'axis' },
    legend: { data: ['收入', '支出'] },
    xAxis: { type: 'category', data: data.map((d) => d.month) },
    yAxis: { type: 'value', axisLabel: { formatter: (v: number) => `¥${v / 100}` } },
    series: [
      { name: '收入', type: 'bar', data: data.map((d) => d.income), itemStyle: { color: '#67c23a' } },
      { name: '支出', type: 'bar', data: data.map((d) => d.expense), itemStyle: { color: '#f56c6c' } },
    ],
  })
}

function renderCategoryChart(data: CategoryStats[]) {
  if (!categoryChartRef.value) return
  const chart = echarts.init(categoryChartRef.value)
  chart.setOption({
    tooltip: { trigger: 'item', formatter: '{b}: ¥{c} ({d}%)' },
    series: [{
      type: 'pie',
      radius: ['40%', '70%'],
      data: data.map((d) => ({ name: `分类${d.category_id}`, value: d.total / 100 })),
    }],
  })
}

onMounted(async () => {
  const now = new Date()
  const year = now.getFullYear()
  const { start, end } = getMonthRange()

  try {
    const [summaryRes, catRes, monthRes, txnRes] = await Promise.all([
      getSummary({ start, end }),
      getByCategory({ start, end }),
      getByMonth({ year }),
      getTransactions({ page_size: 10 }),
    ])
    Object.assign(summary, summaryRes.data)
    categoryData.value = catRes.data
    monthlyData.value = monthRes.data
    // 后端返回 {items, total, ...} 格式
    recentTxns.value = txnRes.data.items || txnRes.data

    renderMonthlyChart(monthlyData.value)
    renderCategoryChart(categoryData.value)
  } catch {
    // ignore on first load
  }
})
</script>

<style scoped>
.summary-cards .summary-item {
  text-align: center;
}
.summary-label {
  font-size: 14px;
  color: #909399;
  margin-bottom: 8px;
}
.summary-value {
  font-size: 24px;
  font-weight: 600;
}
.income { color: #67c23a; }
.expense { color: #f56c6c; }
</style>
