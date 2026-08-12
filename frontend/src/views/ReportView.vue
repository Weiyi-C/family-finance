<template>
  <div>
    <div class="page-header">
      <h3>报表中心</h3>
      <div class="flex items-center gap-12">
        <el-date-picker v-model="dateRange" type="daterange" start-placeholder="开始日期" end-placeholder="结束日期"
          value-format="YYYY-MM-DD" @change="loadReport" class="w-260" />
        <el-button @click="setQuickRange('this_month')">本月</el-button>
        <el-button @click="setQuickRange('last_month')">上月</el-button>
        <el-button @click="setQuickRange('this_year')">今年</el-button>
        <el-button type="primary" @click="handleExport" :loading="exporting">
          <el-icon><Download /></el-icon> 导出CSV
        </el-button>
      </div>
    </div>

    <el-tabs v-model="activeTab" @tab-change="loadReport">
      <!-- 收支报表 -->
      <el-tab-pane label="收支报表" name="income-expense">
        <el-row :gutter="16" class="mb-16">
          <el-col :span="6">
            <el-card shadow="hover">
              <div class="stat-card">
                <div class="stat-label">总收入</div>
                <div class="stat-value text-income">{{ formatMoney(ieReport.summary?.total_income || 0) }}</div>
              </div>
            </el-card>
          </el-col>
          <el-col :span="6">
            <el-card shadow="hover">
              <div class="stat-card">
                <div class="stat-label">总支出</div>
                <div class="stat-value text-expense">{{ formatMoney(ieReport.summary?.total_expense || 0) }}</div>
              </div>
            </el-card>
          </el-col>
          <el-col :span="6">
            <el-card shadow="hover">
              <div class="stat-card">
                <div class="stat-label">净收支</div>
                <div class="stat-value" :class="(ieReport.summary?.net || 0) >= 0 ? 'text-income' : 'text-expense'">
                  {{ formatMoney(ieReport.summary?.net || 0) }}
                </div>
              </div>
            </el-card>
          </el-col>
          <el-col :span="6">
            <el-card shadow="hover">
              <div class="stat-card">
                <div class="stat-label">月均支出</div>
                <div class="stat-value">{{ formatMoney(ieReport.summary?.avg_monthly_expense || 0) }}</div>
              </div>
            </el-card>
          </el-col>
        </el-row>
        <el-card>
          <el-table :data="ieReport.periods || []" stripe>
            <el-table-column prop="period" label="期间" width="100" />
            <el-table-column label="收入" align="right">
              <template #default="{ row }"><span class="text-income">{{ formatMoney(row.income) }}</span></template>
            </el-table-column>
            <el-table-column label="支出" align="right">
              <template #default="{ row }"><span class="text-expense">{{ formatMoney(row.expense) }}</span></template>
            </el-table-column>
            <el-table-column label="净收支" align="right">
              <template #default="{ row }"><span :class="row.net >= 0 ? 'text-income' : 'text-expense'">{{ formatMoney(row.net) }}</span></template>
            </el-table-column>
            <el-table-column label="环比" align="right" width="100">
              <template #default="{ row }">
                <span v-if="row.expense_change !== null" :class="row.expense_change <= 0 ? 'text-income' : 'text-expense'">
                  {{ row.expense_change > 0 ? '+' : '' }}{{ row.expense_change }}%
                </span>
              </template>
            </el-table-column>
            <el-table-column prop="count" label="笔数" width="70" align="right" />
          </el-table>
        </el-card>
      </el-tab-pane>

      <!-- 资产负债报表 -->
      <el-tab-pane label="资产负债" name="balance-sheet">
        <el-row :gutter="16" class="mb-16">
          <el-col :span="8">
            <el-card shadow="hover">
              <div class="stat-card">
                <div class="stat-label">总资产</div>
                <div class="stat-value text-income">{{ formatMoney(bsReport.total_assets || 0) }}</div>
              </div>
            </el-card>
          </el-col>
          <el-col :span="8">
            <el-card shadow="hover">
              <div class="stat-card">
                <div class="stat-label">总负债</div>
                <div class="stat-value text-expense">{{ formatMoney(bsReport.total_liabilities || 0) }}</div>
              </div>
            </el-card>
          </el-col>
          <el-col :span="8">
            <el-card shadow="hover">
              <div class="stat-card">
                <div class="stat-label">净资产</div>
                <div class="stat-value" :class="(bsReport.net_worth || 0) >= 0 ? 'text-income' : 'text-expense'">
                  {{ formatMoney(bsReport.net_worth || 0) }}
                </div>
              </div>
            </el-card>
          </el-col>
        </el-row>
        <el-row :gutter="16">
          <el-col :span="12">
            <el-card>
              <template #header><span>资产账户</span></template>
              <el-table :data="bsReport.assets || []" size="small" stripe>
                <el-table-column prop="name" label="账户" />
                <el-table-column label="余额" align="right">
                  <template #default="{ row }">{{ formatMoney(row.balance) }}</template>
                </el-table-column>
              </el-table>
            </el-card>
          </el-col>
          <el-col :span="12">
            <el-card>
              <template #header><span>负债账户</span></template>
              <el-table :data="bsReport.liabilities || []" size="small" stripe>
                <el-table-column prop="name" label="账户" />
                <el-table-column label="余额" align="right">
                  <template #default="{ row }"><span class="text-expense">{{ formatMoney(row.balance) }}</span></template>
                </el-table-column>
              </el-table>
            </el-card>
          </el-col>
        </el-row>
      </el-tab-pane>

      <!-- 现金流报表 -->
      <el-tab-pane label="现金流" name="cash-flow">
        <el-row :gutter="16" class="mb-16">
          <el-col :span="8">
            <el-card shadow="hover">
              <div class="stat-card">
                <div class="stat-label">总流入</div>
                <div class="stat-value text-income">{{ formatMoney(cfReport.summary?.total_inflow || 0) }}</div>
              </div>
            </el-card>
          </el-col>
          <el-col :span="8">
            <el-card shadow="hover">
              <div class="stat-card">
                <div class="stat-label">总流出</div>
                <div class="stat-value text-expense">{{ formatMoney(cfReport.summary?.total_outflow || 0) }}</div>
              </div>
            </el-card>
          </el-col>
          <el-col :span="8">
            <el-card shadow="hover">
              <div class="stat-card">
                <div class="stat-label">净现金流</div>
                <div class="stat-value" :class="(cfReport.summary?.net_flow || 0) >= 0 ? 'text-income' : 'text-expense'">
                  {{ formatMoney(cfReport.summary?.net_flow || 0) }}
                </div>
              </div>
            </el-card>
          </el-col>
        </el-row>
        <el-card>
          <el-table :data="cfReport.months || []" stripe>
            <el-table-column prop="month" label="月份" width="100" />
            <el-table-column label="流入" align="right">
              <template #default="{ row }"><span class="text-income">{{ formatMoney(row.inflow) }}</span></template>
            </el-table-column>
            <el-table-column label="流出" align="right">
              <template #default="{ row }"><span class="text-expense">{{ formatMoney(row.outflow) }}</span></template>
            </el-table-column>
            <el-table-column label="净现金流" align="right">
              <template #default="{ row }"><span :class="row.net_flow >= 0 ? 'text-income' : 'text-expense'">{{ formatMoney(row.net_flow) }}</span></template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-tab-pane>

      <!-- 分类明细报表 -->
      <el-tab-pane label="分类明细" name="category-detail">
        <div class="mb-16">
          <el-radio-group v-model="catType" @change="loadReport">
            <el-radio-button value="expense">支出</el-radio-button>
            <el-radio-button value="income">收入</el-radio-button>
          </el-radio-group>
        </div>
        <el-card>
          <div class="mb-12">
            <span class="text-regular">合计：</span>
            <span class="font-bold text-xl" :class="catType === 'expense' ? 'text-expense' : 'text-income'">
              {{ formatMoney(catReport.grand_total || 0) }}
            </span>
          </div>
          <el-table :data="catReport.categories || []" stripe row-key="category_id">
            <el-table-column prop="category_name" label="分类" width="150" />
            <el-table-column label="金额" align="right">
              <template #default="{ row }">
                <span :class="catType === 'expense' ? 'text-expense' : 'text-income'">{{ formatMoney(row.total) }}</span>
              </template>
            </el-table-column>
            <el-table-column label="占比" width="100" align="right">
              <template #default="{ row }">
                <el-progress :percentage="row.percentage" :stroke-width="8" :show-text="false" style="width: 60px; display: inline-block;" />
                <span class="text-sm ml-4">{{ row.percentage }}%</span>
              </template>
            </el-table-column>
            <el-table-column prop="count" label="笔数" width="70" align="right" />
            <el-table-column type="expand">
              <template #default="{ row }">
                <el-table :data="row.transactions || []" size="small" stripe>
                  <el-table-column prop="time" label="时间" width="150" />
                  <el-table-column prop="merchant" label="商户" width="150" />
                  <el-table-column prop="description" label="描述" />
                  <el-table-column label="金额" align="right" width="100">
                    <template #default="{ row: t }">{{ formatMoney(t.amount) }}</template>
                  </el-table-column>
                </el-table>
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Download } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import api from '@/api'

const activeTab = ref('income-expense')
const dateRange = ref<[string, string] | null>(null)
const exporting = ref(false)
const catType = ref('expense')

const ieReport = ref<Record<string, unknown>>({})
const bsReport = ref<Record<string, unknown>>({})
const cfReport = ref<Record<string, unknown>>({})
const catReport = ref<Record<string, unknown>>({})

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

function setQuickRange(range: string) {
  const now = new Date()
  if (range === 'this_month') {
    const start = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
    const end = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()}`
    dateRange.value = [start, end]
  } else if (range === 'last_month') {
    const d = new Date(now.getFullYear(), now.getMonth() - 1, 1)
    const start = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`
    const end = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()}`
    dateRange.value = [start, end]
  } else if (range === 'this_year') {
    dateRange.value = [`${now.getFullYear()}-01-01`, `${now.getFullYear()}-12-31`]
  }
  loadReport()
}

async function loadReport() {
  const params: Record<string, string> = {}
  if (dateRange.value) {
    params.start = dateRange.value[0]
    params.end = dateRange.value[1]
  }

  try {
    if (activeTab.value === 'income-expense') {
      const res = await api.get('/reports/income-expense', { params: { ...params, group_by: 'month' } })
      ieReport.value = res.data
    } else if (activeTab.value === 'balance-sheet') {
      const res = await api.get('/reports/balance-sheet')
      bsReport.value = res.data
    } else if (activeTab.value === 'cash-flow') {
      const res = await api.get('/reports/cash-flow', { params })
      cfReport.value = res.data
    } else if (activeTab.value === 'category-detail') {
      const res = await api.get('/reports/category-detail', { params: { ...params, type: catType.value } })
      catReport.value = res.data
    }
  } catch { /* ignore */ }
}

async function handleExport() {
  exporting.value = true
  try {
    const params: Record<string, string> = { report_type: activeTab.value }
    if (dateRange.value) {
      params.start = dateRange.value[0]
      params.end = dateRange.value[1]
    }
    if (activeTab.value === 'category-detail') params.type = catType.value

    const res = await api.get('/reports/export', { params, responseType: 'blob' })
    const url = URL.createObjectURL(res.data)
    const a = document.createElement('a')
    a.href = url
    a.download = `${activeTab.value}.csv`
    a.click()
    URL.revokeObjectURL(url)
    ElMessage.success('导出成功')
  } catch { ElMessage.error('导出失败') }
  finally { exporting.value = false }
}

onMounted(loadReport)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 12px; }
.page-header h3 { margin: 0; }
</style>
