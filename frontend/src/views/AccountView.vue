<template>
  <div>
    <div class="page-header">
      <h3>账户管理</h3>
      <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon> 新建账户</el-button>
    </div>
    <el-card>
      <el-table :data="accounts" stripe v-loading="loading">
        <el-table-column prop="name" label="名称" />
        <el-table-column label="类型" width="120">
          <template #default="{ row }">
            <span>{{ getTemplateName(row.type_code) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="bank_name" label="银行" width="120" />
        <el-table-column label="余额" align="right" width="140">
          <template #default="{ row }">{{ formatMoney(row.balance) }}</template>
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
        <el-form-item label="类型">
          <el-select v-model="form.type_code" style="width: 100%;" @change="onTypeChange">
            <el-option-group v-for="group in templateGroups" :key="group.name" :label="group.name">
              <el-option v-for="t in group.templates" :key="t.type_code" :label="`${t.icon} ${t.name}`" :value="t.type_code" />
            </el-option-group>
          </el-select>
        </el-form-item>
        <el-form-item label="名称"><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="银行" v-if="needBank">
          <el-select v-model="form.bank_name" filterable placeholder="选择银行" style="width: 100%;">
            <el-option v-for="b in banks" :key="b.id" :label="b.name" :value="b.name" />
          </el-select>
        </el-form-item>
        <el-form-item label="卡号后四位" v-if="needCard"><el-input v-model="form.card_tail" maxlength="4" /></el-form-item>
        <el-form-item label="手机号" v-if="needPhone"><el-input v-model="form.phone" /></el-form-item>
        <el-form-item label="邮箱" v-if="needEmail"><el-input v-model="form.email" /></el-form-item>
        <el-form-item label="初始余额(元)"><el-input-number v-model="form.initialBalanceYuan" :precision="2" style="width: 100%;" /></el-form-item>
        <el-form-item label="信用额度(元)" v-if="needCreditLimit"><el-input-number v-model="form.credit_limit_yuan" :min="0" :precision="2" style="width: 100%;" /></el-form-item>
        <el-form-item label="账单日" v-if="needBillingDay"><el-input-number v-model="form.billing_day" :min="1" :max="28" /></el-form-item>
        <el-form-item label="还款日" v-if="needDueDay"><el-input-number v-model="form.due_day" :min="1" :max="28" /></el-form-item>
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
import { ref, reactive, computed, onMounted } from 'vue'
import { Plus } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getAccounts, createAccount, updateAccount, deleteAccount } from '@/api/accounts'
import { getBanks, getAccountTemplates } from '@/api/reference'
import type { PaymentAccount } from '@/types'

interface BankItem { id: number; name: string; code: string; short_name: string }
interface TemplateItem { id: number; type_code: string; name: string; icon: string | null; group_name: string; is_credit: boolean; has_credit_limit: boolean; has_billing_day: boolean; has_due_day: boolean }

const loading = ref(false)
const saving = ref(false)
const accounts = ref<PaymentAccount[]>([])
const banks = ref<BankItem[]>([])
const templates = ref<TemplateItem[]>([])
const showDialog = ref(false)
const editingId = ref<number | null>(null)

const form = reactive({
  type_code: '', name: '', bank_name: '', card_tail: '', phone: '', email: '',
  initialBalanceYuan: 0, credit_limit_yuan: 0,
  billing_day: null as number | null, due_day: null as number | null, notes: '',
})

const currentTemplate = computed(() => templates.value.find((t) => t.type_code === form.type_code))
const needBank = computed(() => ['bank_savings', 'bank_credit'].includes(form.type_code))
const needCard = computed(() => ['bank_savings', 'bank_credit'].includes(form.type_code))
const needPhone = computed(() => ['alipay_balance', 'wechat_balance', 'alipay_huabei'].includes(form.type_code))
const needEmail = computed(() => form.type_code === 'alipay_balance')
const needCreditLimit = computed(() => currentTemplate.value?.has_credit_limit ?? false)
const needBillingDay = computed(() => currentTemplate.value?.has_billing_day ?? false)
const needDueDay = computed(() => currentTemplate.value?.has_due_day ?? false)

const templateGroups = computed(() => {
  const groups: Record<string, TemplateItem[]> = {}
  for (const t of templates.value) {
    if (!groups[t.group_name]) groups[t.group_name] = []
    groups[t.group_name].push(t)
  }
  return Object.entries(groups).map(([name, ts]) => ({ name, templates: ts }))
})

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

function getTemplateName(typeCode: string) {
  return templates.value.find((t) => t.type_code === typeCode)?.name || typeCode
}

function onTypeChange() {
  const t = currentTemplate.value
  if (t) form.name = t.name
}

async function load() {
  loading.value = true
  try { accounts.value = (await getAccounts(true)).data } finally { loading.value = false }
}

function openCreate() {
  editingId.value = null
  form.type_code = 'cash'; form.name = '现金'; form.bank_name = ''; form.card_tail = ''
  form.phone = ''; form.email = ''; form.initialBalanceYuan = 0; form.credit_limit_yuan = 0
  form.billing_day = null; form.due_day = null; form.notes = ''
  showDialog.value = true
}

function editAccount(row: PaymentAccount) {
  editingId.value = row.id
  form.type_code = row.type_code; form.name = row.name; form.bank_name = row.bank_name || ''
  form.card_tail = row.card_tail || ''; form.initialBalanceYuan = row.balance / 100
  form.credit_limit_yuan = (row.credit_limit || 0) / 100
  form.billing_day = row.billing_day; form.due_day = row.due_day
  form.notes = row.notes || ''
  showDialog.value = true
}

async function handleSave() {
  if (!form.name) { ElMessage.warning('请填写名称'); return }
  saving.value = true
  try {
    const payload: Record<string, unknown> = {
      name: form.name, type_code: form.type_code,
      initial_balance: Math.round(form.initialBalanceYuan * 100),
    }
    if (form.bank_name) payload.bank_name = form.bank_name
    if (form.card_tail) payload.card_tail = form.card_tail
    if (form.credit_limit_yuan) payload.credit_limit = Math.round(form.credit_limit_yuan * 100)
    if (form.billing_day) payload.billing_day = form.billing_day
    if (form.due_day) payload.due_day = form.due_day
    if (form.notes) payload.notes = form.notes

    if (editingId.value) {
      await updateAccount(editingId.value, payload as any); ElMessage.success('更新成功')
    } else {
      await createAccount(payload as any); ElMessage.success('创建成功')
    }
    showDialog.value = false; editingId.value = null; await load()
  } catch (err: unknown) {
    ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '保存失败')
  } finally { saving.value = false }
}

async function handleArchive(id: number) {
  try { await deleteAccount(id); ElMessage.success('已归档'); await load() } catch { ElMessage.error('操作失败') }
}

onMounted(async () => {
  await Promise.all([
    load(),
    getBanks().then((r) => { banks.value = r.data }),
    getAccountTemplates().then((r) => { templates.value = r.data }),
  ])
})
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
