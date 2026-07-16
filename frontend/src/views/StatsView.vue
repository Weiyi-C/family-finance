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
          <template #header><span>商户排行</span></template>
          <el-table :data="merchantData" stripe>
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
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import { getByMonth, getByCategory, getByDay, getMerchantRanking } from '@/api/stats'
import type { MerchantRank } from '@/types'

const monthlyRef = ref<HTMLElement>()
const categoryRef = ref<HTMLElement>()
const dailyRef = ref<HTMLElement>()

const chartType = ref('expense')
const year = ref(String(new Date().getFullYear()))
const merchantData = ref<MerchantRank[]>([])

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

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
}

onMounted(load)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
