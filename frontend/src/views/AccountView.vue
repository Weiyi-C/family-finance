<template>
  <div>
    <div class="page-header">
      <h3>账户管理</h3>
      <el-button type="primary" @click="showDialog = true"><el-icon><Plus /></el-icon> 新建账户</el-button>
    </div>
    <el-card>
      <el-table :data="accounts" stripe v-loading="loading">
        <el-table-column prop="name" label="名称" />
        <el-table-column prop="type_code" label="类型" width="120" />
        <el-table-column prop="bank_name" label="银行" width="120" />
        <el-table-column prop="currency" label="币种" width="70" />
        <el-table-column label="余额" align="right" width="140">
          <template #default="{ row }">{{ formatMoney(row.balance) }}</template>
        </el-table-column>
        <el-table-column prop="is_default" label="默认" width="70">
          <template #default="{ row }"><el-tag v-if="row.is_default" size="small">默认</el-tag></template>
        </el-table-column>
        <el-table-column label="操作" width="140">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="editAccount(row)">编辑</el-button>
            <el-popconfirm title="确定归档？" @confirm="handleArchive(row.id)">
              <template #reference><el-button link type="danger" size="small">归档</el-button></template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showDialog" :title="editingId ? '编辑账户' : '新建账户'" width="500px" destroy-on-close>
      <el-form :model="form" label-width="80px">
        <el-form-item label="名称"><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="类型">
          <el-select v-model="form.type_code" style="width: 100%;">
            <el-option v-for="t in accountTypes" :key="t" :label="t" :value="t" />
          </el-select>
        </el-form-item>
        <el-form-item label="银行"><el-input v-model="form.bank_name" /></el-form-item>
        <el-form-item label="币种"><el-input v-model="form.currency" placeholder="CNY" /></el-form-item>
        <el-form-item label="初始余额(元)"><el-input-number v-model="form.initialBalanceYuan" :precision="2" style="width: 100%;" /></el-form-item>
        <el-form-item label="卡号后四位"><el-input v-model="form.card_tail" maxlength="4" /></el-form-item>
        <el-form-item label="备注"><el-input v-model="form.notes" type="textarea" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Plus } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getAccounts, createAccount, updateAccount, deleteAccount } from '@/api/accounts'
import type { PaymentAccount } from '@/types'

const loading = ref(false)
const saving = ref(false)
const accounts = ref<PaymentAccount[]>([])
const showDialog = ref(false)
const editingId = ref<number | null>(null)

const accountTypes = ['cash', 'debit_card', 'credit_card', 'alipay', 'wechat', 'other']

const form = reactive({
  name: '', type_code: 'debit_card', bank_name: '', currency: 'CNY',
  initialBalanceYuan: 0, card_tail: '', notes: '',
})

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

async function load() {
  loading.value = true
  try {
    const res = await getAccounts(true)
    accounts.value = res.data
  } finally { loading.value = false }
}

function editAccount(row: PaymentAccount) {
  editingId.value = row.id
  form.name = row.name
  form.type_code = row.type_code
  form.bank_name = row.bank_name || ''
  form.currency = row.currency
  form.initialBalanceYuan = row.balance / 100
  form.card_tail = row.card_tail || ''
  form.notes = row.notes || ''
  showDialog.value = true
}

async function handleSave() {
  if (!form.name) { ElMessage.warning('请填写名称'); return }
  saving.value = true
  try {
    const payload = {
      name: form.name, type_code: form.type_code, bank_name: form.bank_name || undefined,
      currency: form.currency, initial_balance: Math.round(form.initialBalanceYuan * 100),
      card_tail: form.card_tail || undefined, notes: form.notes || undefined,
    }
    if (editingId.value) {
      await updateAccount(editingId.value, payload)
      ElMessage.success('更新成功')
    } else {
      await createAccount(payload)
      ElMessage.success('创建成功')
    }
    showDialog.value = false
    editingId.value = null
    await load()
  } catch (err: unknown) {
    ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '保存失败')
  } finally { saving.value = false }
}

async function handleArchive(id: number) {
  try { await deleteAccount(id); ElMessage.success('已归档'); await load() } catch { ElMessage.error('操作失败') }
}

onMounted(load)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
