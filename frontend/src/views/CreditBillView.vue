<template>
  <div>
    <div class="page-header">
      <h3>信用卡账单</h3>
      <div>
        <span class="summary-text" v-if="summary">待还总额: <b>{{ formatMoney(summary.total_due) }}</b> ({{ summary.bill_count }}笔)</span>
      </div>
    </div>
    <el-card>
      <el-table :data="bills" stripe v-loading="loading">
        <el-table-column label="账期" width="120">
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
        <el-table-column label="最低还款" align="right">
          <template #default="{ row }">{{ formatMoney(row.min_payment) }}</template>
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
import { getCreditBills, payCreditBill, getCreditBillSummary } from '@/api/creditBills'
import type { CreditBill } from '@/api/creditBills'

const loading = ref(false)
const bills = ref<CreditBill[]>([])
const summary = ref<{ total_due: number; bill_count: number } | null>(null)
const showPay = ref(false)
const payBillId = ref(0)
const payAmount = ref(0)

const statusMap: Record<string, string> = { pending: '待还', partial: '部分', paid: '已还', overdue: '逾期' }
const statusType: Record<string, string> = { pending: 'warning', partial: '', paid: 'success', overdue: 'danger' }

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

async function load() {
  loading.value = true
  try {
    const [billsRes, summaryRes] = await Promise.all([getCreditBills(), getCreditBillSummary()])
    bills.value = billsRes.data; summary.value = summaryRes.data
  } finally { loading.value = false }
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
