<template>
  <div>
    <div class="page-header">
      <h3>数据分析</h3>
      <div class="flex items-center gap-12">
        <el-radio-group v-model="period" @change="onPeriodChange" size="small">
          <el-radio-button value="this_week">本周</el-radio-button>
          <el-radio-button value="this_month">本月</el-radio-button>
          <el-radio-button value="last_month">上月</el-radio-button>
          <el-radio-button value="this_year">今年</el-radio-button>
          <el-radio-button value="custom">自定义</el-radio-button>
        </el-radio-group>
        <el-date-picker v-if="period === 'custom'" v-model="customRange" type="daterange"
          start-placeholder="开始" end-placeholder="结束" value-format="YYYY-MM-DD" @change="loadAll" class="w-260" />
        <span class="text-sm text-muted">{{ periodLabel }}</span>
      </div>
    </div>

    <el-tabs v-model="activeTab" @tab-change="onTabChange">
      <!-- ========== Tab 1: 概览 ========== -->
      <el-tab-pane label="概览" name="overview">
        <!-- 摘要卡片 -->
        <el-row :gutter="16" class="mb-16">
          <el-col :span="6" v-for="card in summaryCards" :key="card.label">
            <el-card shadow="hover">
              <div class="stat-card">
                <div class="stat-label">{{ card.label }}</div>
                <div class="stat-value" :class="card.class">{{ card.value }}</div>
                <div v-if="card.change !== undefined" class="text-sm mt-4" :class="card.changeClass">
                  {{ card.change }}
                </div>
              </div>
            </el-card>
          </el-col>
        </el-row>

        <!-- 资产总览 + 预算进度 -->
        <el-row :gutter="16" class="mb-16">
          <el-col :span="12">
            <el-card>
              <template #header>
                <div class="flex justify-between items-center">
                  <span>资产总览</span>
                  <span class="text-xl font-bold" :class="totalAssets >= 0 ? 'text-income' : 'text-expense'">
                    {{ formatMoney(totalAssets) }}
                  </span>
                </div>
              </template>
              <div v-if="assetGroups.length === 0" class="text-center text-muted p-20">暂无账户数据</div>
              <div v-for="g in assetGroups" :key="g.label" class="flex justify-between items-center mb-8">
                <span>{{ g.icon }} {{ g.label }}</span>
                <span class="font-medium" :class="g.total < 0 ? 'text-expense' : ''">{{ formatMoney(g.total) }}</span>
              </div>
            </el-card>
          </el-col>
          <el-col :span="12">
            <el-card>
              <template #header><span>本月预算</span></template>
              <div v-if="budgetUsages.length === 0" class="text-center text-muted p-20">暂未设置预算</div>
              <div v-for="bu in budgetUsages" :key="bu.budget_id" class="mb-12">
                <div class="flex justify-between mb-4">
                  <span class="text-sm">{{ bu.category_name || '总预算' }}</span>
                  <span class="text-sm text-muted">{{ formatMoney(bu.spent) }} / {{ formatMoney(bu.amount) }}</span>
                </div>
                <el-progress :percentage="Math.min(bu.usage_rate * 100, 100)"
                  :status="bu.is_over ? 'exception' : bu.usage_rate > (bu.alert_threshold || 0.8) ? 'warning' : ''"
                  :stroke-width="10" />
              </div>
            </el-card>
          </el-col>
        </el-row>

        <!-- 最近交易 -->
        <el-card>
          <template #header><span>最近交易</span></template>
          <el-table :data="recentTxns" stripe size="small">
            <el-table-column prop="transaction_time" label="时间" width="170">
              <template #default="{ row }">{{ formatTime(row.transaction_time) }}</template>
            </el-table-column>
            <el-table-column prop="type" label="类型" width="70">
              <template #default="{ row }"><el-tag :type="typeTag[row.type]" size="small">{{ typeMap[row.type] }}</el-tag></template>
            </el-table-column>
            <el-table-column prop="merchant_name" label="商户" />
            <el-table-column prop="description" label="备注" />
            <el-table-column prop="amount" label="金额" align="right" width="120">
              <template #default="{ row }">
                <span v-if="row.type === 'transfer'" class="text-muted">{{ formatMoney(row.amount) }}</span>
                <span v-else :class="row.type === 'expense' ? 'text-expense' : 'text-income'">
                  {{ row.type === 'expense' ? '-' : '+' }}{{ formatMoney(row.amount) }}
                </span>
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-tab-pane>

      <!-- ========== Tab 2: 趋势分析 ========== -->
      <el-tab-pane label="趋势分析" name="trends">
        <div class="mb-16">
          <el-radio-group v-model="chartType" @change="loadTrends" size="small">
            <el-radio-button value="expense">支出</el-radio-button>
            <el-radio-button value="income">收入</el-radio-button>
          </el-radio-group>
        </div>
        <el-row :gutter="16">
          <el-col :span="12">
            <el-card>
              <template #header><span>月度趋势</span></template>
              <div ref="monthlyRef" class="h-320"></div>
            </el-card>
          </el-col>
          <el-col :span="12">
            <el-card>
              <template #header><span>分类占比</span></template>
              <div ref="categoryRef" class="h-320"></div>
            </el-card>
          </el-col>
        </el-row>
        <el-card class="mt-16">
          <template #header><span>日趋势</span></template>
          <div ref="dailyRef" class="h-300"></div>
        </el-card>
      </el-tab-pane>

      <!-- ========== Tab 3: 报表 ========== -->
      <el-tab-pane label="报表" name="reports">
        <div class="flex items-center gap-12 mb-16">
          <el-button @click="handleExport" :loading="exporting" size="small">
            <el-icon><Download /></el-icon> 导出CSV
          </el-button>
          <el-radio-group v-model="reportType" @change="loadReport" size="small">
            <el-radio-button value="income-expense">收支报表</el-radio-button>
            <el-radio-button value="balance-sheet">资产负债</el-radio-button>
            <el-radio-button value="cash-flow">现金流</el-radio-button>
            <el-radio-button value="category-detail">分类明细</el-radio-button>
          </el-radio-group>
          <el-radio-group v-if="reportType === 'category-detail'" v-model="catType" @change="loadReport" size="small">
            <el-radio-button value="expense">支出</el-radio-button>
            <el-radio-button value="income">收入</el-radio-button>
          </el-radio-group>
        </div>

        <!-- 收支报表 -->
        <template v-if="reportType === 'income-expense'">
          <el-row :gutter="16" class="mb-16">
            <el-col :span="6" v-for="s in ieSummaryCards" :key="s.label">
              <el-card shadow="hover"><div class="stat-card"><div class="stat-label">{{ s.label }}</div><div class="stat-value" :class="s.class">{{ s.value }}</div></div></el-card>
            </el-col>
          </el-row>
          <el-card>
            <el-table :data="ieReport.periods || []" stripe size="small">
              <el-table-column prop="period" label="期间" width="100" />
              <el-table-column label="收入" align="right"><template #default="{ row }"><span class="text-income">{{ formatMoney(row.income) }}</span></template></el-table-column>
              <el-table-column label="支出" align="right"><template #default="{ row }"><span class="text-expense">{{ formatMoney(row.expense) }}</span></template></el-table-column>
              <el-table-column label="净收支" align="right"><template #default="{ row }"><span :class="row.net >= 0 ? 'text-income' : 'text-expense'">{{ formatMoney(row.net) }}</span></template></el-table-column>
              <el-table-column label="环比" align="right" width="80"><template #default="{ row }"><span v-if="row.expense_change !== null" :class="row.expense_change <= 0 ? 'text-income' : 'text-expense'">{{ row.expense_change > 0 ? '+' : '' }}{{ row.expense_change }}%</span></template></el-table-column>
              <el-table-column prop="count" label="笔数" width="60" align="right" />
            </el-table>
          </el-card>
        </template>

        <!-- 资产负债 -->
        <template v-if="reportType === 'balance-sheet'">
          <el-row :gutter="16" class="mb-16">
            <el-col :span="8"><el-card shadow="hover"><div class="stat-card"><div class="stat-label">总资产</div><div class="stat-value text-income">{{ formatMoney(bsReport.total_assets || 0) }}</div></div></el-card></el-col>
            <el-col :span="8"><el-card shadow="hover"><div class="stat-card"><div class="stat-label">总负债</div><div class="stat-value text-expense">{{ formatMoney(bsReport.total_liabilities || 0) }}</div></div></el-card></el-col>
            <el-col :span="8"><el-card shadow="hover"><div class="stat-card"><div class="stat-label">净资产</div><div class="stat-value" :class="(bsReport.net_worth || 0) >= 0 ? 'text-income' : 'text-expense'">{{ formatMoney(bsReport.net_worth || 0) }}</div></div></el-card></el-col>
          </el-row>
          <el-row :gutter="16">
            <el-col :span="12"><el-card><template #header><span>资产账户</span></template><el-table :data="bsReport.assets || []" size="small" stripe><el-table-column prop="name" label="账户" /><el-table-column label="余额" align="right"><template #default="{ row }">{{ formatMoney(row.balance) }}</template></el-table-column></el-table></el-card></el-col>
            <el-col :span="12"><el-card><template #header><span>负债账户</span></template><el-table :data="bsReport.liabilities || []" size="small" stripe><el-table-column prop="name" label="账户" /><el-table-column label="余额" align="right"><template #default="{ row }"><span class="text-expense">{{ formatMoney(row.balance) }}</span></template></el-table-column></el-table></el-card></el-col>
          </el-row>
        </template>

        <!-- 现金流 -->
        <template v-if="reportType === 'cash-flow'">
          <el-row :gutter="16" class="mb-16">
            <el-col :span="8"><el-card shadow="hover"><div class="stat-card"><div class="stat-label">总流入</div><div class="stat-value text-income">{{ formatMoney(cfReport.summary?.total_inflow || 0) }}</div></div></el-card></el-col>
            <el-col :span="8"><el-card shadow="hover"><div class="stat-card"><div class="stat-label">总流出</div><div class="stat-value text-expense">{{ formatMoney(cfReport.summary?.total_outflow || 0) }}</div></div></el-card></el-col>
            <el-col :span="8"><el-card shadow="hover"><div class="stat-card"><div class="stat-label">净现金流</div><div class="stat-value" :class="(cfReport.summary?.net_flow || 0) >= 0 ? 'text-income' : 'text-expense'">{{ formatMoney(cfReport.summary?.net_flow || 0) }}</div></div></el-card></el-col>
          </el-row>
          <el-card>
            <el-table :data="cfReport.months || []" stripe size="small">
              <el-table-column prop="month" label="月份" width="100" />
              <el-table-column label="流入" align="right"><template #default="{ row }"><span class="text-income">{{ formatMoney(row.inflow) }}</span></template></el-table-column>
              <el-table-column label="流出" align="right"><template #default="{ row }"><span class="text-expense">{{ formatMoney(row.outflow) }}</span></template></el-table-column>
              <el-table-column label="净现金流" align="right"><template #default="{ row }"><span :class="row.net_flow >= 0 ? 'text-income' : 'text-expense'">{{ formatMoney(row.net_flow) }}</span></template></el-table-column>
            </el-table>
          </el-card>
        </template>

        <!-- 分类明细 -->
        <template v-if="reportType === 'category-detail'">
          <el-card>
            <div class="mb-12"><span class="text-regular">合计：</span><span class="font-bold text-xl" :class="catType === 'expense' ? 'text-expense' : 'text-income'">{{ formatMoney(catReport.grand_total || 0) }}</span></div>
            <el-table :data="catReport.categories || []" stripe size="small" row-key="category_id">
              <el-table-column prop="category_name" label="分类" width="150" />
              <el-table-column label="金额" align="right"><template #default="{ row }"><span :class="catType === 'expense' ? 'text-expense' : 'text-income'">{{ formatMoney(row.total) }}</span></template></el-table-column>
              <el-table-column label="占比" width="120" align="right"><template #default="{ row }"><el-progress :percentage="row.percentage" :stroke-width="8" :show-text="false" style="width: 60px; display: inline-block;" /><span class="text-sm ml-4">{{ row.percentage }}%</span></template></el-table-column>
              <el-table-column prop="count" label="笔数" width="60" align="right" />
              <el-table-column type="expand"><template #default="{ row }"><el-table :data="row.transactions || []" size="small" stripe><el-table-column prop="time" label="时间" width="150" /><el-table-column prop="merchant" label="商户" width="150" /><el-table-column prop="description" label="描述" /><el-table-column label="金额" align="right" width="100"><template #default="{ row: t }">{{ formatMoney(t.amount) }}</template></el-table-column></el-table></template></el-table-column>
            </el-table>
          </el-card>
        </template>
      </el-tab-pane>

      <!-- ========== Tab 4: 深度分析 ========== -->
      <el-tab-pane label="深度分析" name="analysis">
        <!-- 商户排行 -->
        <el-card class="mb-16">
          <template #header><span>商户排行 TOP10</span></template>
          <el-table :data="merchantData" stripe size="small">
            <el-table-column type="index" width="50" />
            <el-table-column prop="merchant" label="商户" />
            <el-table-column label="金额" align="right"><template #default="{ row }">{{ formatMoney(row.total) }}</template></el-table-column>
            <el-table-column prop="count" label="笔数" width="70" />
          </el-table>
        </el-card>

        <!-- 分类排行 -->
        <el-card class="mb-16">
          <template #header><span>分类排行</span></template>
          <el-table :data="categoryRankData" stripe size="small">
            <el-table-column type="index" width="50" label="排名" />
            <el-table-column label="分类" width="150"><template #default="{ row }">{{ getCategoryName(row.category_id) }}</template></el-table-column>
            <el-table-column label="金额" align="right" width="120"><template #default="{ row }">{{ formatMoney(row.total) }}</template></el-table-column>
            <el-table-column prop="count" label="笔数" width="80" />
            <el-table-column label="占比" min-width="200"><template #default="{ row }"><el-progress :percentage="categoryTotal > 0 ? Math.round(row.total / categoryTotal * 100) : 0" :stroke-width="12" :format="(p: number) => `${p}%`" /></template></el-table-column>
          </el-table>
        </el-card>

        <!-- 交叉分析 -->
        <el-card>
          <template #header>
            <div class="flex justify-between items-center">
              <span>交叉分析</span>
              <div class="flex gap-12">
                <el-select v-model="crossDim1" size="small" class="w-120" @change="loadCross">
                  <el-option label="按分类" value="category" /><el-option label="按账户" value="account" />
                  <el-option label="按渠道" value="channel" /><el-option label="按平台" value="platform" />
                </el-select>
                <el-select v-model="crossDim2" size="small" class="w-120" @change="loadCross">
                  <el-option label="按月" value="month" /><el-option label="按日" value="day" /><el-option label="按星期" value="weekday" />
                </el-select>
              </div>
            </div>
          </template>
          <div ref="crossRef" class="h-350"></div>
        </el-card>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import { Download } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import * as echarts from 'echarts'
import { getChartColors } from '@/utils/chartTheme'
import api from '@/api'
import { getSummary, getByCategory, getByDay, getByMonth, getMerchantRanking, getComparison, getCrossAnalysis } from '@/api/stats'
import { getTransactions } from '@/api/transactions'
import { getAccounts } from '@/api/accounts'
import { getCategories } from '@/api/categories'
import { getBudgets, getBudgetUsage } from '@/api/budgets'
import type { StatsSummary, CategoryStats, DailyStats, Transaction, PaymentAccount, Category, Budget, BudgetUsage, ComparisonResult, MerchantRank, CrossAnalysisItem } from '@/types'

// ==================== 状态 ====================
const activeTab = ref('overview')
const period = ref('this_month')
const customRange = ref<[string, string] | null>(null)
const chartType = ref('expense')
const reportType = ref('income-expense')
const catType = ref('expense')
const exporting = ref(false)

// 概览数据
const summary = reactive<StatsSummary>({ total_income: 0, total_expense: 0, net: 0, count: 0 })
const comparison = ref<ComparisonResult | null>(null)
const recentTxns = ref<Transaction[]>([])
const accounts = ref<PaymentAccount[]>([])
const categoriesFlat = ref<Category[]>([])
const budgetUsages = ref<(BudgetUsage & { category_name: string | null; alert_threshold: number })[]>([])

// 趋势数据
const merchantData = ref<MerchantRank[]>([])
const categoryRankData = ref<CategoryStats[]>([])
const categoryTotal = computed(() => categoryRankData.value.reduce((sum, d) => sum + d.total, 0))

// 报表数据
const ieReport = ref<Record<string, unknown>>({})
const bsReport = ref<Record<string, unknown>>({})
const cfReport = ref<Record<string, unknown>>({})
const catReport = ref<Record<string, unknown>>({})

// 交叉分析
const crossData = ref<CrossAnalysisItem[]>([])
const crossDim1 = ref('category')
const crossDim2 = ref('month')

// 图表 ref
const monthlyRef = ref<HTMLElement>()
const categoryRef = ref<HTMLElement>()
const dailyRef = ref<HTMLElement>()
const crossRef = ref<HTMLElement>()

const categoryMap = computed(() => {
  const map: Record<number, string> = {}
  for (const c of categoriesFlat.value) map[c.id] = c.name
  return map
})

const typeMap: Record<string, string> = { expense: '支出', income: '收入', transfer: '资金转移' }
const typeTag: Record<string, string> = { expense: 'danger', income: 'success', transfer: 'info' }
const weekdayNames = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']

// ==================== 格式化 ====================
function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }
function formatTime(t: string) { return t ? new Date(t).toLocaleString('zh-CN') : '' }
function formatChange(val: number | null): string {
  if (val === null || val === undefined) return ''
  return `${val > 0 ? '↑' : val < 0 ? '↓' : ''}${Math.abs(val).toFixed(1)}%`
}
function formatDate(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}
function getCategoryName(id: number) { return categoriesFlat.value.find((c) => c.id === id)?.name || `分类${id}` }

// ==================== 时间范围 ====================
function getDateRange(): { start: string; end: string } {
  const now = new Date()
  const y = now.getFullYear(), m = now.getMonth(), d = now.getDate(), dow = now.getDay() || 7
  switch (period.value) {
    case 'this_week': { const mon = new Date(now); mon.setDate(d - dow + 1); return { start: formatDate(mon), end: formatDate(now) } }
    case 'this_month': return { start: `${y}-${String(m + 1).padStart(2, '0')}-01`, end: formatDate(now) }
    case 'last_month': { const lm = new Date(y, m - 1, 1); return { start: formatDate(lm), end: formatDate(new Date(y, m, 0)) } }
    case 'this_year': return { start: `${y}-01-01`, end: formatDate(now) }
    case 'custom': return customRange.value ? { start: customRange.value[0], end: customRange.value[1] } : { start: `${y}-${String(m + 1).padStart(2, '0')}-01`, end: formatDate(now) }
    default: return { start: `${y}-01-01`, end: formatDate(now) }
  }
}
const periodLabel = computed(() => { const { start, end } = getDateRange(); return `${start} 至 ${end}` })
function onPeriodChange(val: string) { if (val !== 'custom') loadAll() }

// ==================== 概览数据 ====================
const summaryCards = computed(() => {
  const cards = [
    { label: '收入', value: formatMoney(summary.total_income), class: 'text-income' },
    { label: '支出', value: formatMoney(summary.total_expense), class: 'text-expense' },
    { label: '净收支', value: formatMoney(summary.net), class: summary.net >= 0 ? 'text-income' : 'text-expense' },
    { label: '交易笔数', value: String(summary.count), class: '' },
  ]
  if (comparison.value) {
    const c = comparison.value.changes
    cards[0].change = formatChange(c.income_change)
    cards[0].changeClass = (c.income_change ?? 0) >= 0 ? 'text-income' : 'text-expense'
    cards[1].change = formatChange(c.expense_change)
    cards[1].changeClass = (c.expense_change ?? 0) <= 0 ? 'text-income' : 'text-expense'
  }
  return cards
})

const totalAssets = computed(() => accounts.value.reduce((sum, a) => sum + ((a as any).balance ?? a.initial_balance ?? 0), 0))
const assetGroups = computed(() => {
  const groups: Record<string, { icon: string; label: string; total: number }> = {}
  for (const a of accounts.value) {
    if (!a.is_active || a.is_hidden) continue
    let key: string, icon: string, label: string
    if (a.type_code?.startsWith('bank_')) { key = 'bank'; icon = '🏦'; label = '银行卡' }
    else if (a.type_code?.includes('alipay') || a.type_code?.includes('wechat')) { key = 'ewallet'; icon = '📱'; label = '电子钱包' }
    else if (a.type_code === 'cash') { key = 'cash'; icon = '💵'; label = '现金' }
    else if (a.type_code?.includes('credit') || a.type_code === 'alipay_huabei' || a.type_code === 'jd_baitiao') { key = 'credit'; icon = '💳'; label = '信用账户' }
    else { key = 'other'; icon = '💰'; label = '其他' }
    if (!groups[key]) groups[key] = { icon, label, total: 0 }
    groups[key].total += (a as any).balance ?? a.initial_balance ?? 0
  }
  return Object.values(groups)
})

const ieSummaryCards = computed(() => [
  { label: '总收入', value: formatMoney((ieReport.value.summary as any)?.total_income || 0), class: 'text-income' },
  { label: '总支出', value: formatMoney((ieReport.value.summary as any)?.total_expense || 0), class: 'text-expense' },
  { label: '净收支', value: formatMoney((ieReport.value.summary as any)?.net || 0), class: ((ieReport.value.summary as any)?.net || 0) >= 0 ? 'text-income' : 'text-expense' },
  { label: '月均支出', value: formatMoney((ieReport.value.summary as any)?.avg_monthly_expense || 0), class: '' },
])

// ==================== 数据加载 ====================
async function loadAll() {
  const { start, end } = getDateRange()
  await Promise.all([loadOverview(start, end), loadTrends(), loadReport(), loadCross()])
}

async function loadOverview(start: string, end: string) {
  try {
    const [summaryRes, txnRes] = await Promise.all([
      getSummary({ start, end }),
      getTransactions({ start_date: start, end_date: end, page_size: 10 }),
    ])
    Object.assign(summary, summaryRes.data)
    recentTxns.value = txnRes.data.items || txnRes.data
  } catch { /* ignore */ }
}

async function loadTrends() {
  const { start, end } = getDateRange()
  try {
    const [monthRes, catRes, dayRes, merchantRes] = await Promise.all([
      getByMonth({ year: new Date().getFullYear(), type: chartType.value }),
      getByCategory({ type: chartType.value, limit: 10, start, end }),
      getByDay({ type: chartType.value, start, end }),
      getMerchantRanking({ limit: 10, start, end }),
    ])
    await nextTick()
    if (monthlyRef.value) {
      echarts.init(monthlyRef.value).setOption({
        tooltip: { trigger: 'axis' },
        xAxis: { type: 'category', data: monthRes.data.map((d: any) => d.month) },
        yAxis: { type: 'value', axisLabel: { formatter: (v: number) => `¥${v / 100}` } },
        series: [{ type: 'bar', data: monthRes.data.map((d: any) => chartType.value === 'expense' ? d.expense : d.income), itemStyle: { color: chartType.value === 'expense' ? getChartColors().expense : getChartColors().income } }],
      })
    }
    if (categoryRef.value) {
      echarts.init(categoryRef.value).setOption({
        tooltip: { trigger: 'item', formatter: (p: any) => `${p.name}: ¥${p.value.toFixed(2)} (${p.percent}%)` },
        series: [{ type: 'pie', radius: ['40%', '70%'], data: catRes.data.map((d: any) => ({ name: getCategoryName(d.category_id), value: d.total / 100 })), label: { formatter: '{b}: {d}%' } }],
      })
    }
    if (dailyRef.value) {
      echarts.init(dailyRef.value).setOption({
        tooltip: { trigger: 'axis' },
        xAxis: { type: 'category', data: dayRes.data.map((d: any) => d.date.slice(5)) },
        yAxis: { type: 'value', axisLabel: { formatter: (v: number) => `¥${v / 100}` } },
        series: [{ type: 'line', data: dayRes.data.map((d: any) => d.total), smooth: true, areaStyle: { opacity: 0.3 }, itemStyle: { color: getChartColors().primary } }],
      })
    }
    merchantData.value = merchantRes.data
    categoryRankData.value = catRes.data
  } catch { /* ignore */ }
}

async function loadComparison() {
  try {
    const now = new Date(), y = now.getFullYear(), m = now.getMonth()
    const curStart = `${y}-${String(m + 1).padStart(2, '0')}-01`
    const curEnd = `${y}-${String(m + 1).padStart(2, '0')}-${String(new Date(y, m + 1, 0).getDate()).padStart(2, '0')}`
    const prevY = m === 0 ? y - 1 : y, prevM = m === 0 ? 12 : m
    const prevStart = `${prevY}-${String(prevM).padStart(2, '0')}-01`
    const prevEnd = `${prevY}-${String(prevM).padStart(2, '0')}-${String(new Date(prevY, prevM, 0).getDate()).padStart(2, '0')}`
    const res = await getComparison({ current: `${curStart}:${curEnd}`, previous: `${prevStart}:${prevEnd}` })
    comparison.value = res.data
  } catch { /* ignore */ }
}

async function loadReport() {
  const { start, end } = getDateRange()
  const params: Record<string, string> = { start, end }
  try {
    if (reportType.value === 'income-expense') {
      const res = await api.get('/reports/income-expense', { params: { ...params, group_by: 'month' } })
      ieReport.value = res.data
    } else if (reportType.value === 'balance-sheet') {
      bsReport.value = (await api.get('/reports/balance-sheet')).data
    } else if (reportType.value === 'cash-flow') {
      cfReport.value = (await api.get('/reports/cash-flow', { params })).data
    } else if (reportType.value === 'category-detail') {
      catReport.value = (await api.get('/reports/category-detail', { params: { ...params, type: catType.value } })).data
    }
  } catch { /* ignore */ }
}

async function loadCross() {
  try {
    const { start, end } = getDateRange()
    const res = await getCrossAnalysis({ dimension1: crossDim1.value, dimension2: crossDim2.value, start, end })
    crossData.value = res.data
    await nextTick()
    if (!crossRef.value || !crossData.value.length) return
    const dim1Values = [...new Set(crossData.value.map((d) => d.dim1))]
    const dim2Values = [...new Set(crossData.value.map((d) => d.dim2))]
    const heatData: [number, number, number][] = []
    for (let i = 0; i < dim1Values.length; i++)
      for (let j = 0; j < dim2Values.length; j++) {
        const item = crossData.value.find((d) => d.dim1 === dim1Values[i] && d.dim2 === dim2Values[j])
        heatData.push([j, i, item ? item.total / 100 : 0])
      }
    const getDimName = (dim: string, id: string) => {
      const n = Number(id)
      if (dim === 'category') return getCategoryName(n)
      if (dim === 'account') return accounts.value.find((a) => a.id === n)?.name || id
      if (dim === 'weekday') return weekdayNames[Number(id)] || id
      return id
    }
    echarts.init(crossRef.value).setOption({
      tooltip: { formatter: (p: any) => `${getDimName(crossDim1.value, dim1Values[p.data[1]])} × ${getDimName(crossDim2.value, dim2Values[p.data[0]])}<br/>¥${p.data[2].toFixed(2)}` },
      xAxis: { type: 'category', data: dim2Values.map((v) => getDimName(crossDim2.value, v)), axisLabel: { rotate: dim2Values.length > 10 ? 45 : 0 } },
      yAxis: { type: 'category', data: dim1Values.map((v) => getDimName(crossDim1.value, v)) },
      visualMap: { min: 0, max: Math.max(...heatData.map((d) => d[2]), 1), calculable: true, orient: 'horizontal', left: 'center', bottom: 0, inRange: { color: [getChartColors().bgPage, getChartColors().primary] } },
      series: [{ type: 'heatmap', data: heatData, label: { show: dim1Values.length * dim2Values.length < 60, formatter: (p: any) => p.data[2] > 0 ? `¥${p.data[2].toFixed(0)}` : '' } }],
      grid: { left: 100, right: 20, top: 20, bottom: 60 },
    })
  } catch { /* ignore */ }
}

async function loadBudgets() {
  try {
    const now = new Date()
    const budgetsRes = await getBudgets({ year: now.getFullYear(), month: now.getMonth() + 1 })
    const budgets: Budget[] = budgetsRes.data
    const usages = []
    for (const b of budgets) {
      try {
        const usageRes = await getBudgetUsage(b.id)
        usages.push({ ...usageRes.data, category_name: b.category_id ? (categoryMap.value[b.category_id] || `分类${b.category_id}`) : null, alert_threshold: b.alert_threshold ?? 0.8 })
      } catch { /* skip */ }
    }
    budgetUsages.value = usages
  } catch { /* ignore */ }
}

async function handleExport() {
  exporting.value = true
  try {
    const { start, end } = getDateRange()
    const params: Record<string, string> = { report_type: reportType.value, start, end }
    if (reportType.value === 'category-detail') params.type = catType.value
    const res = await api.get('/reports/export', { params, responseType: 'blob' })
    const url = URL.createObjectURL(res.data)
    const a = document.createElement('a'); a.href = url; a.download = `${reportType.value}.csv`; a.click()
    URL.revokeObjectURL(url); ElMessage.success('导出成功')
  } catch { ElMessage.error('导出失败') }
  finally { exporting.value = false }
}

function onTabChange(tab: string) {
  if (tab === 'trends') nextTick(() => loadTrends())
  if (tab === 'reports') loadReport()
  if (tab === 'analysis') { loadTrends(); loadCross() }
}

// ==================== 初始化 ====================
onMounted(async () => {
  const catRes = await getCategories()
  const flat: Category[] = []
  function flatten(items: Category[]) { for (const c of items) { flat.push(c); if (c.children) flatten(c.children) } }
  flatten(catRes.data)
  categoriesFlat.value = flat

  accounts.value = (await getAccounts()).data
  loadAll()
  loadComparison()
  loadBudgets()
})
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 12px; }
.page-header h3 { margin: 0; }
</style>
