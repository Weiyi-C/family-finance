<template>
  <div>
    <div class="page-header">
      <h3>汇率管理</h3>
      <el-button type="primary" :loading="loading" @click="refreshRates">
        <el-icon><Refresh /></el-icon>
        刷新汇率
      </el-button>
    </div>

    <el-card v-loading="loading">
      <template #header>
        <div class="card-header">
          <span>当前汇率（基准：CNY 人民币）</span>
          <span class="update-time" v-if="lastUpdate">最后更新：{{ lastUpdate }}</span>
        </div>
      </template>

      <el-table :data="exchangeRates" stripe style="width: 100%">
        <el-table-column label="目标货币" min-width="120">
          <template #default="{ row }">
            <div class="currency-cell">
              <span class="currency-code">{{ row.target_currency }}</span>
              <span class="currency-name">{{ getCurrencyName(row.target_currency) }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="汇率" min-width="120">
          <template #default="{ row }">
            <span class="rate-value">{{ row.rate.toFixed(6) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="换算" min-width="150">
          <template #default="{ row }">
            <span class="convert-text">1 CNY = {{ row.rate.toFixed(4) }} {{ row.target_currency }}</span>
          </template>
        </el-table-column>
        <el-table-column label="反向汇率" min-width="120">
          <template #default="{ row }">
            <span class="reverse-rate">{{ (1 / row.rate).toFixed(4) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="来源" min-width="100">
          <template #default="{ row }">
            <el-tag size="small">{{ row.source }}</el-tag>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Refresh } from '@element-plus/icons-vue'
import { getExchangeRates } from '@/api/exchange'
import type { ExchangeRate } from '@/api/exchange'

const loading = ref(false)
const exchangeRates = ref<ExchangeRate[]>([])
const lastUpdate = ref('')

const currencyNames: Record<string, string> = {
  USD: '美元',
  EUR: '欧元',
  JPY: '日元',
  GBP: '英镑',
  HKD: '港币',
  AUD: '澳元',
  CAD: '加元',
  SGD: '新加坡元',
  CHF: '瑞士法郎',
  SEK: '瑞典克朗',
  NOK: '挪威克朗',
  DKK: '丹麦克朗',
  NZD: '新西兰元',
  KRW: '韩元',
  THB: '泰铢',
  MYR: '马来西亚林吉特',
  IDR: '印尼盾',
  PHP: '菲律宾比索',
  VND: '越南盾',
  INR: '印度卢比',
  RUB: '俄罗斯卢布',
  BRL: '巴西雷亚尔',
  ZAR: '南非兰特',
  MXN: '墨西哥比索',
  AED: '阿联酋迪拉姆',
  SAR: '沙特里亚尔',
  QAR: '卡塔尔里亚尔',
  KWD: '科威特第纳尔',
  BHD: '巴林第纳尔',
  OMR: '阿曼里亚尔',
}

function getCurrencyName(code: string): string {
  return currencyNames[code] || code
}

async function loadRates() {
  loading.value = true
  try {
    const res = await getExchangeRates()
    exchangeRates.value = res.data
    if (res.data.length > 0) {
      lastUpdate.value = res.data[0].rate_date
    }
  } catch (err) {
    console.error('加载汇率失败', err)
    ElMessage.error('加载汇率失败')
  } finally {
    loading.value = false
  }
}

async function refreshRates() {
  await loadRates()
  ElMessage.success('汇率已刷新')
}

onMounted(loadRates)
</script>

<style scoped>
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}
.page-header h3 {
  margin: 0;
}
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.update-time {
  font-size: 12px;
  color: var(--color-text-secondary);
}
.currency-cell {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.currency-code {
  font-weight: 600;
  color: var(--color-text-primary);
}
.currency-name {
  font-size: 12px;
  color: var(--color-text-secondary);
}
.rate-value {
  font-weight: 600;
  color: var(--color-primary);
}
.convert-text {
  font-size: 13px;
  color: var(--color-text-regular);
}
.reverse-rate {
  color: var(--color-text-secondary);
}
</style>
