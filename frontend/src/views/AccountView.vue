<template>
  <div>
    <div class="page-header">
      <h3>账户管理</h3>
      <el-button type="primary" @click="showCreateDialog = true"><el-icon><Plus /></el-icon> 新建账户</el-button>
    </div>

    <!-- 按分组显示账户 -->
    <div v-for="group in accountGroups" :key="group.label" style="margin-bottom: 16px;">
      <el-card>
        <template #header>
          <div style="display: flex; justify-content: space-between; align-items: center;">
            <span>{{ group.icon }} {{ group.label }} ({{ group.accounts.length }}个)</span>
            <el-button size="small" @click="openAddProduct(group)">添加产品</el-button>
          </div>
        </template>
        <el-table :data="group.accounts" stripe size="small">
          <el-table-column label="名称" min-width="150">
            <template #default="{ row }">
              <span>{{ row.icon || '' }} {{ row.name }}</span>
              <el-tag v-if="row.linked_account_id" size="small" type="warning" style="margin-left: 8px;">代付</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="类型" width="100">
            <template #default="{ row }">{{ getTemplateName(row.type_code) }}</template>
          </el-table-column>
          <el-table-column label="余额" align="right" width="120">
            <template #default="{ row }">
              <span :class="row.initial_balance < 0 ? 'text-expense' : ''">{{ formatMoney(row.initial_balance) }}</span>
            </template>
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
    </div>

    <!-- 新建账户对话框 -->
    <AccountCreateDialog
      v-model="showCreateDialog"
      :banks="banks"
      :channels="channels"
      :accounts="accounts"
      @created="onAccountCreated"
    />

    <!-- 编辑对话框 -->
    <el-dialog v-model="showEditDialog" title="编辑账户" width="500px" destroy-on-close>
      <el-form :model="editForm" label-width="100px">
        <el-form-item label="名称"><el-input v-model="editForm.name" /></el-form-item>
        <el-form-item label="初始余额(元)"><el-input-number v-model="editForm.initialBalanceYuan" :precision="2" style="width: 100%;" /></el-form-item>
        <el-form-item label="备注"><el-input v-model="editForm.notes" type="textarea" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showEditDialog = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleUpdate">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { Plus } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getAccounts, updateAccount, deleteAccount } from '@/api/accounts'
import { getBanks, getAccountTemplates } from '@/api/reference'
import { getChannels } from '@/api/channels'
import AccountCreateDialog from '@/components/AccountCreateDialog.vue'
import type { PaymentAccount, Channel } from '@/types'

interface BankItem { id: number; name: string; code: string; short_name: string }
interface TemplateItem { id: number; type_code: string; name: string; icon: string | null }

const loading = ref(false)
const saving = ref(false)
const accounts = ref<PaymentAccount[]>([])
const banks = ref<BankItem[]>([])
const templates = ref<TemplateItem[]>([])
const channels = ref<Channel[]>([])
const showCreateDialog = ref(false)
const showEditDialog = ref(false)
const editForm = reactive({ id: 0, name: '', initialBalanceYuan: 0, notes: '' })

// 账户分组 - 支持同一平台多个账号
const accountGroups = computed(() => {
  const groups: Record<string, { icon: string; label: string; accounts: PaymentAccount[] }> = {}

  // 找出所有顶级账户（没有parent_id的）
  const topAccounts = accounts.value.filter((a) => a.is_active && !a.is_hidden && !a.parent_id)
  // 找出所有子账户
  const childAccounts = accounts.value.filter((a) => a.is_active && !a.is_hidden && a.parent_id)

  // 处理顶级账户
  for (const a of topAccounts) {
    let key: string, icon: string, label: string

    if (a.channel_id) {
      // 平台账号顶级账户（如"支付宝-138xxxx"）
      const c = channels.value.find((c) => c.id === a.channel_id)
      icon = c?.name.includes('支付宝') ? '📱' : c?.name.includes('微信') ? '💬' : '🌐'
      // 使用账户名称作为分组标签（包含账号标识）
      key = `parent_${a.id}`
      label = a.name
    } else if (a.bank_id) {
      // 银行顶级账户
      const b = banks.value.find((b) => b.id === a.bank_id)
      key = `bank_${a.bank_id}`
      icon = '🏦'
      label = b?.name || '银行'
    } else if (a.type_code === 'cash') {
      key = 'cash'
      icon = '💵'
      label = '现金'
    } else {
      key = 'other'
      icon = '💰'
      label = '其他'
    }

    if (!groups[key]) groups[key] = { icon, label, accounts: [] }
    groups[key].accounts.push(a)
  }

  // 处理子账户（归入父账户的分组）
  for (const a of childAccounts) {
    const parent = accounts.value.find((p) => p.id === a.parent_id)
    if (parent) {
      const key = `parent_${parent.id}`
      if (!groups[key]) {
        // 父账户可能不在当前列表中，创建一个分组
        const c = channels.value.find((c) => c.id === parent.channel_id)
        const icon = c?.name.includes('支付宝') ? '📱' : c?.name.includes('微信') ? '💬' : '🌐'
        groups[key] = { icon, label: parent.name, accounts: [] }
      }
      groups[key].accounts.push(a)
    } else {
      // 父账户不存在，放入"其他"
      if (!groups['other']) groups['other'] = { icon: '💰', label: '其他', accounts: [] }
      groups['other'].accounts.push(a)
    }
  }

  return Object.values(groups)
})

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }
function getTemplateName(typeCode: string) { return templates.value.find((t) => t.type_code === typeCode)?.name || typeCode }

function openAddProduct(_group: { label: string }) {
  // 打开新建对话框，可根据分组预选渠道
  showCreateDialog.value = true
}

function onAccountCreated() {
  load()
}

function editAccount(row: PaymentAccount) {
  editForm.id = row.id
  editForm.name = row.name
  editForm.initialBalanceYuan = row.initial_balance / 100
  editForm.notes = ''
  showEditDialog.value = true
}

async function handleUpdate() {
  if (!editForm.name) { ElMessage.warning('请填写名称'); return }
  saving.value = true
  try {
    await updateAccount(editForm.id, {
      name: editForm.name,
      initial_balance: Math.round(editForm.initialBalanceYuan * 100),
      notes: editForm.notes || undefined,
    } as any)
    ElMessage.success('更新成功')
    showEditDialog.value = false
    await load()
  } catch { ElMessage.error('更新失败') }
  finally { saving.value = false }
}

async function handleArchive(id: number) {
  try { await deleteAccount(id); ElMessage.success('已归档'); await load() } catch { ElMessage.error('操作失败') }
}

async function load() {
  loading.value = true
  try { accounts.value = (await getAccounts(true)).data } finally { loading.value = false }
}

onMounted(async () => {
  await Promise.all([
    load(),
    getBanks().then((r) => { banks.value = r.data }),
    getAccountTemplates().then((r) => { templates.value = r.data }),
    getChannels().then((r) => { channels.value = r.data }),
  ])
})
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
.text-expense { color: #f56c6c; }
</style>
