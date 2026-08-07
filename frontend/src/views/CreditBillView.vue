<template>
  <div>
    <div class="page-header">
      <h3>信用卡账单</h3>
      <div>
        <span class="summary-text" v-if="summary">待还总额: <b>{{ formatMoney(summary.total_due) }}</b> ({{ summary.bill_count }}笔)</span>
      </div>
    </div>

    <!-- 生成账单 -->
    <el-card style="margin-bottom: 16px;">
      <div style="display: flex; align-items: center; gap: 12px;">
        <span style="font-size: 14px; color: #606266;">生成账单：</span>
        <el-date-picker
          v-model="genMonth"
          type="month"
          placeholder="选择月份"
          value-format="YYYY-MM"
          style="width: 160px;"
        />
        <el-button type="primary" :loading="generating" @click="handleGenerate">生成</el-button>
      </div>
    </el-card>

    <el-card>
      <el-table :data="bills" stripe v-loading="loading">
        <el-table-column label="信用卡" width="200">
          <template #default="{ row }">{{ getAccountName(row.account_id) }}</template>
        </el-table-column>
        <el-table-column label="账期" width="100">
          <template #default="{ row }">{{ row.bill_year }}-{{ String(row.bill_month).padStart(2, '0') }}</template>
        </el-table-column>
        <el-table-column prop="billing_date" label="出账日" width="110" />
        <el-table-column prop="due_date" label="还款日" width="110" />
        <el-table-column label="账单金额" align="right">
          <template #default="{ row }">{{ formatMoney(row.total_amount) }}</template>
        </el-table-column>
        <el-table-column label="已还" align="right">
          <template #default="{ row }">{{ formatMoney(row.paid_amount) }}</template>
        </el-table-column>
        <el-table-column label="待还" align="right">
          <template #default="{ row }">
            <span style="color: #f56c6c; font-weight: 600;">{{ formatMoney(row.total_amount - row.paid_amount) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="statusType[row.status]" size="small">{{ statusMap[row.status] }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="100">
          <template #default="{ row }">
            <el-button v-if="row.status !== 'paid'" link type="primary" size="small" @click="openPay(row)">还款</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showPay" title="信用卡还款" width="360px">
      <el-form label-width="80px">
        <el-form-item label="还款金额(分)"><el-input-number v-model="payAmount" :min="1" style="width: 100%;" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showPay = false">取消</el-button>
        <el-button type="primary" @click="handlePay">确认</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getCreditBills, payCreditBill, getCreditBillSummary, generateCreditBills } from '@/api/creditBills'
import { getAccounts } from '@/api/accounts'
import type { CreditBill } from '@/api/creditBills'
import type { PaymentAccount } from '@/types'

const loading = ref(false)
const generating = ref(false)
const bills = ref<CreditBill[]>([])
const accounts = ref<PaymentAccount[]>([])
const summary = ref<{ total_due: number; bill_count: number } | null>(null)
const showPay = ref(false)
const payBillId = ref(0)
const payAmount = ref(0)
const genMonth = ref('')

const statusMap: Record<string, string> = { pending: '待还', partial: '部分', paid: '已还', overdue: '逾期' }
const statusType: Record<string, string> = { pending: 'warning', partial: '', paid: 'success', overdue: 'danger' }

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

function getAccountName(accountId: number) {
  return accounts.value.find((a) => a.id === accountId)?.name || `账户${accountId}`
}

async function load() {
  loading.value = true
  try {
    const [billsRes, summaryRes, accountsRes] = await Promise.all([
      getCreditBills(),
      getCreditBillSummary(),
      getAccounts(),
    ])
    bills.value = billsRes.data
    summary.value = summaryRes.data
    accounts.value = accountsRes.data
  } finally { loading.value = false }
}

async function handleGenerate() {
  if (!genMonth.value) { ElMessage.warning('请选择月份'); return }
  const [year, month] = genMonth.value.split('-').map(Number)
  generating.value = true
  try {
    const res = await generateCreditBills(year, month)
    ElMessage.success(res.data.message)
    await load()
  } catch (err: any) {
    ElMessage.error(err?.response?.data?.detail || '生成失败')
  } finally { generating.value = false }
}

function openPay(row: CreditBill) { payBillId.value = row.id; payAmount.value = row.total_amount - row.paid_amount; showPay.value = true }

async function handlePay() {
  if (!payAmount.value) { ElMessage.warning('请填写金额'); return }
  try { await payCreditBill(payBillId.value, payAmount.value); ElMessage.success('还款成功'); showPay.value = false; await load() }
  catch { ElMessage.error('还款失败') }
}

onMounted(load)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
.summary-text { font-size: 14px; color: #606266; }
.summary-text b { color: #f56c6c; }
</style>
