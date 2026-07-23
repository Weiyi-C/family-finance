<template>
  <div>
    <div class="page-header">
      <h3>统计分析</h3>
      <div>
        <el-radio-group v-model="chartType" @change="load">
          <el-radio-button value="expense">支出</el-radio-button>
          <el-radio-button value="income">收入</el-radio-button>
        </el-radio-group>
        <el-date-picker v-model="year" type="year" value-format="YYYY" @change="load" style="width: 120px; margin-left: 12px;" />
      </div>
    </div>

    <!-- 环比对比 -->
    <el-card style="margin-bottom: 16px;">
      <template #header><span>本月 vs 上月 环比</span></template>
      <el-row :gutter="20">
        <el-col :span="6" v-for="item in comparisonCards" :key="item.label">
          <div style="text-align: center; padding: 12px;">
            <div style="font-size: 13px; color: #909399; margin-bottom: 8px;">{{ item.label }}</div>
            <div style="font-size: 20px; font-weight: 600;">{{ item.value }}</div>
            <div style="font-size: 13px; margin-top: 4px;" :style="{ color: item.changeColor }">
              {{ item.changeText }}
            </div>
          </div>
        </el-col>
      </el-row>
    </el-card>

    <el-row :gutter="16">
      <el-col :span="12">
        <el-card>
          <template #header><span>月度趋势</span></template>
          <div ref="monthlyRef" style="height: 320px;"></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header><span>分类占比</span></template>
          <div ref="categoryRef" style="height: 320px;"></div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16" style="margin-top: 16px;">
      <el-col :span="12">
        <el-card>
          <template #header><span>日趋势</span></template>
          <div ref="dailyRef" style="height: 300px;"></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header><span>商户排行 TOP10</span></template>
          <el-table :data="merchantData" stripe size="small">
            <el-table-column type="index" width="50" />
            <el-table-column prop="merchant" label="商户" />
            <el-table-column label="金额" align="right">
              <template #default="{ row }">{{ formatMoney(row.total) }}</template>
            </el-table-column>
            <el-table-column prop="count" label="笔数" width="70" />
          </el-table>
        </el-card>
      </el-col>
    </el-row>

    <!-- 分类排行 -->
    <el-card style="margin-top: 16px;">
      <template #header><span>分类排行</span></template>
      <el-table :data="categoryRankData" stripe size="small">
        <el-table-column type="index" width="50" label="排名" />
        <el-table-column label="分类" width="150">
          <template #default="{ row }">{{ getCategoryName(row.category_id) }}</template>
        </el-table-column>
        <el-table-column label="金额" align="right" width="120">
          <template #default="{ row }">{{ formatMoney(row.total) }}</template>
        </el-table-column>
        <el-table-column prop="count" label="笔数" width="80" />
        <el-table-column label="占比" min-width="200">
          <template #default="{ row }">
            <el-progress
              :percentage="categoryTotal > 0 ? Math.round(row.total / categoryTotal * 100) : 0"
              :stroke-width="12"
              :format="(p: number) => `${p}%`"
            />
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 交叉分析 -->
    <el-card style="margin-top: 16px;">
      <template #header>
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <span>交叉分析</span>
          <div style="display: flex; gap: 12px;">
            <el-select v-model="crossDim1" size="small" style="width: 120px;" @change="loadCross">
              <el-option label="按分类" value="category" />
              <el-option label="按账户" value="account" />
              <el-option label="按渠道" value="channel" />
              <el-option label="按平台" value="platform" />
            </el-select>
            <el-select v-model="crossDim2" size="small" style="width: 120px;" @change="loadCross">
              <el-option label="按月" value="month" />
              <el-option label="按日" value="day" />
              <el-option label="按星期" value="weekday" />
            </el-select>
          </div>
        </div>
      </template>
      <div ref="crossRef" style="height: 350px;"></div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import { getByMonth, getByCategory, getByDay, getMerchantRanking, getComparison, getCrossAnalysis } from '@/api/stats'
import { getCategories } from '@/api/categories'
import type { MerchantRank, ComparisonResult, CrossAnalysisItem, CategoryStats, Category } from '@/types'

const monthlyRef = ref<HTMLElement>()
const categoryRef = ref<HTMLElement>()
const dailyRef = ref<HTMLElement>()
const crossRef = ref<HTMLElement>()

const chartType = ref('expense')
const year = ref(String(new Date().getFullYear()))
const merchantData = ref<MerchantRank[]>([])
const categoryRankData = ref<CategoryStats[]>([])
const categoryTotal = computed(() => categoryRankData.value.reduce((sum, d) => sum + d.total, 0))
const categoriesFlat = ref<Category[]>([])

function getCategoryName(id: number): string {
  return categoriesFlat.value.find((c) => c.id === id)?.name || `分类${id}`
}
const comparison = ref<ComparisonResult | null>(null)
const crossData = ref<CrossAnalysisItem[]>([])
const crossDim1 = ref('category')
const crossDim2 = ref('month')

const weekdayNames = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

function formatChange(val: number | null): string {
  if (val === null) return '-'
  const sign = val > 0 ? '+' : ''
  return `${sign}${val.toFixed(1)}%`
}

const comparisonCards = computed(() => {
  if (!comparison.value) return []
  const { current, changes } = comparison.value
  return [
    {
      label: '支出',
      value: formatMoney(current.expense),
      changeText: formatChange(changes.expense_change),
      changeColor: changes.expense_change !== null && changes.expense_change > 0 ? '#f56c6c' : '#67c23a',
    },
    {
      label: '收入',
      value: formatMoney(current.income),
      changeText: formatChange(changes.income_change),
      changeColor: changes.income_change !== null && changes.income_change > 0 ? '#67c23a' : '#f56c6c',
    },
    {
      label: '净收支',
      value: formatMoney(current.net),
      changeText: formatChange(changes.net_change),
      changeColor: changes.net_change !== null && changes.net_change >= 0 ? '#67c23a' : '#f56c6c',
    },
    {
      label: '笔数',
      value: String(current.count),
      changeText: formatChange(changes.count_change),
      changeColor: '#909399',
    },
  ]
})

async function loadComparison() {
  try {
    const now = new Date()
    const y = now.getFullYear()
    const m = now.getMonth()
    const curStart = `${y}-${String(m + 1).padStart(2, '0')}-01`
    const curEnd = `${y}-${String(m + 1).padStart(2, '0')}-${String(new Date(y, m + 1, 0).getDate()).padStart(2, '0')}`
    const prevStart = `${y}-${String(m).padStart(2, '0')}-01`
    const prevEnd = `${y}-${String(m).padStart(2, '0')}-${String(new Date(y, m, 0).getDate()).padStart(2, '0')}`

    const res = await getComparison({
      current: `${curStart}:${curEnd}`,
      previous: `${prevStart}:${prevEnd}`,
    })
    comparison.value = res.data
  } catch { /* ignore */ }
}

async function loadCross() {
  try {
    const now = new Date()
    const y = now.getFullYear()
    const start = `${y}-01-01`
    const end = `${y}-12-31`
    const res = await getCrossAnalysis({
      dimension1: crossDim1.value,
      dimension2: crossDim2.value,
      start,
      end,
    })
    crossData.value = res.data
    renderCrossChart()
  } catch { /* ignore */ }
}

function renderCrossChart() {
  if (!crossRef.value || !crossData.value.length) return

  const dim1Values = [...new Set(crossData.value.map((d) => d.dim1))]
  const dim2Values = [...new Set(crossData.value.map((d) => d.dim2))]

  // 构建热力图数据
  const heatData: [number, number, number][] = []
  for (let i = 0; i < dim1Values.length; i++) {
    for (let j = 0; j < dim2Values.length; j++) {
      const item = crossData.value.find((d) => d.dim1 === dim1Values[i] && d.dim2 === dim2Values[j])
      heatData.push([j, i, item ? item.total / 100 : 0])
    }
  }

  const chart = echarts.init(crossRef.value)
  chart.setOption({
    tooltip: {
      formatter: (params: any) => {
        const d = params.data
        return `${dim1Values[d[1]]} × ${dim2Values[d[0]]}<br/>金额: ¥${d[2].toFixed(2)}`
      }
    },
    xAxis: {
      type: 'category',
      data: dim2Values.map((v) => crossDim2.value === 'weekday' ? weekdayNames[Number(v)] || v : v),
      axisLabel: { rotate: dim2Values.length > 10 ? 45 : 0 },
    },
    yAxis: {
      type: 'category',
      data: dim1Values,
    },
    visualMap: {
      min: 0,
      max: Math.max(...heatData.map((d) => d[2]), 1),
      calculable: true,
      orient: 'horizontal',
      left: 'center',
      bottom: 0,
      inRange: { color: ['#f5f5f5', '#409eff'] },
    },
    series: [{
      type: 'heatmap',
      data: heatData,
      label: { show: dim1Values.length * dim2Values.length < 60, formatter: (p: any) => p.data[2] > 0 ? `¥${p.data[2].toFixed(0)}` : '' },
      emphasis: { itemStyle: { shadowBlur: 10, shadowColor: 'rgba(0, 0, 0, 0.5)' } },
    }],
    grid: { left: 80, right: 20, top: 20, bottom: 60 },
  })
}

async function load() {
  const y = Number(year.value)
  const [monthRes, catRes, dayRes, merchantRes] = await Promise.all([
    getByMonth({ year: y, type: chartType.value }),
    getByCategory({ type: chartType.value, limit: 10 }),
    getByDay({ type: chartType.value }),
    getMerchantRanking({ limit: 10 }),
  ])

  await nextTick()

  if (monthlyRef.value) {
    echarts.init(monthlyRef.value).setOption({
      tooltip: { trigger: 'axis' },
      xAxis: { type: 'category', data: monthRes.data.map((d) => d.month) },
      yAxis: { type: 'value', axisLabel: { formatter: (v: number) => `¥${v / 100}` } },
      series: [{ type: 'bar', data: monthRes.data.map((d) => chartType.value === 'expense' ? d.expense : d.income), itemStyle: { color: chartType.value === 'expense' ? '#f56c6c' : '#67c23a' } }],
    })
  }

  if (categoryRef.value) {
    echarts.init(categoryRef.value).setOption({
      tooltip: { trigger: 'item' },
      series: [{ type: 'pie', radius: ['40%', '70%'], data: catRes.data.map((d) => ({ name: `分类${d.category_id}`, value: d.total / 100 })) }],
    })
  }

  if (dailyRef.value) {
    echarts.init(dailyRef.value).setOption({
      tooltip: { trigger: 'axis' },
      xAxis: { type: 'category', data: dayRes.data.map((d) => d.date.slice(5)) },
      yAxis: { type: 'value', axisLabel: { formatter: (v: number) => `¥${v / 100}` } },
      series: [{ type: 'line', data: dayRes.data.map((d) => d.total), smooth: true, areaStyle: {} }],
    })
  }

  merchantData.value = merchantRes.data
  categoryRankData.value = catRes.data
}

async function loadCategories() {
  try {
    const res = await getCategories()
    const flat: Category[] = []
    function flatten(items: Category[]) {
      for (const item of items) {
        flat.push(item)
        if (item.children) flatten(item.children)
      }
    }
    flatten(res.data)
    categoriesFlat.value = flat
  } catch { /* ignore */ }
}

onMounted(() => {
  load()
  loadComparison()
  loadCross()
  loadCategories()
})
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
