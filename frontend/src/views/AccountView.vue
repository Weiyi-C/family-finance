<template>
  <div>
    <div class="page-header">
      <h3>账户管理</h3>
      <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon> 新建账户</el-button>
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

    <!-- 第一步：选择账户类别 -->
    <el-dialog v-model="showCategoryDialog" title="新建账户" width="500px" destroy-on-close>
      <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px;">
        <el-card v-for="cat in categories" :key="cat.value" shadow="hover" style="cursor: pointer; text-align: center;"
          @click="selectCategory(cat.value)">
          <div style="font-size: 36px; margin-bottom: 8px;">{{ cat.icon }}</div>
          <div style="font-weight: 500;">{{ cat.label }}</div>
          <div style="font-size: 12px; color: #909399; margin-top: 4px;">{{ cat.desc }}</div>
        </el-card>
      </div>
    </el-dialog>

    <!-- 第二步A：选择支付渠道 -->
    <el-dialog v-model="showChannelDialog" title="选择支付渠道" width="500px" destroy-on-close>
      <el-form label-width="80px">
        <el-form-item label="支付渠道">
          <el-select v-model="channelForm.channel_id" style="width: 100%;" @change="onChannelSelect">
            <el-option v-for="c in channelOptions" :key="c.id" :label="c.name" :value="c.id" />
          </el-select>
        </el-form-item>

        <el-form-item label="账号" v-if="existingChannelAccounts.length > 0">
          <el-radio-group v-model="channelForm.existing_account_id" style="width: 100%;">
            <el-radio v-for="a in existingChannelAccounts" :key="a.id" :value="a.id" style="display: block; margin-bottom: 8px;">
              {{ a.name }}
            </el-radio>
            <el-radio :value="null" style="display: block;">新建账号</el-radio>
          </el-radio-group>
        </el-form-item>

        <el-form-item label="账号名称" v-if="!channelForm.existing_account_id">
          <el-input v-model="channelForm.account_name" :placeholder="`我的${getChannelName(channelForm.channel_id)}`" />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="showChannelDialog = false">取消</el-button>
        <el-button @click="showCategoryDialog = true; showChannelDialog = false">上一步</el-button>
        <el-button type="primary" @click="goToProductSelect">下一步</el-button>
      </template>
    </el-dialog>

    <!-- 第二步B：选择产品 -->
    <el-dialog v-model="showProductDialog" title="选择产品" width="600px" destroy-on-close>
      <p style="color: #909399; margin-bottom: 16px;">选择要开通的产品：</p>
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
        <el-card v-for="prod in channelProducts" :key="prod.type_code" shadow="hover"
          style="cursor: pointer;" :class="{ 'selected-card': selectedProducts.includes(prod.type_code) }"
          @click="toggleProduct(prod.type_code)">
          <div style="display: flex; align-items: center; gap: 12px;">
            <span style="font-size: 24px;">{{ prod.icon }}</span>
            <div>
              <div style="font-weight: 500;">{{ prod.name }}</div>
              <div style="font-size: 12px; color: #909399;">{{ prod.desc }}</div>
            </div>
            <el-icon v-if="selectedProducts.includes(prod.type_code)" style="color: #67c23a; margin-left: auto;">
              <CircleCheck />
            </el-icon>
          </div>
        </el-card>
      </div>

      <el-divider />

      <el-card shadow="hover" style="cursor: pointer;" @click="showFamilyCard = !showFamilyCard">
        <div style="display: flex; align-items: center; gap: 12px;">
          <span style="font-size: 24px;">👨‍👩‍👧</span>
          <div>
            <div style="font-weight: 500;">亲情卡/代付</div>
            <div style="font-size: 12px; color: #909399;">关联他人账户，付款时从对方账户扣款</div>
          </div>
        </div>
      </el-card>

      <el-form v-if="showFamilyCard" style="margin-top: 16px;" label-width="100px">
        <el-form-item label="关联用户">
          <el-select v-model="familyCardForm.linked_user_id" style="width: 100%;">
            <el-option v-for="u in familyMembers" :key="u.id" :label="u.nickname" :value="u.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="关联扣款账户">
          <el-select v-model="familyCardForm.linked_account_id" style="width: 100%;">
            <el-option v-for="a in allAccounts" :key="a.id" :label="a.name" :value="a.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="账户名称">
          <el-input v-model="familyCardForm.name" placeholder="如：女朋友的亲情卡" />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="showProductDialog = false; showChannelDialog = true">上一步</el-button>
        <el-button type="primary" :loading="saving" @click="handleCreateChannelAccounts">创建</el-button>
      </template>
    </el-dialog>

    <!-- 小荷包创建对话框 -->
    <el-dialog v-model="showXiaoheibaoDialog" title="创建小荷包" width="500px" destroy-on-close>
      <el-form label-width="100px">
        <el-form-item label="小荷包名称">
          <el-input v-model="xiaoheibaoForm.name" placeholder="如：日常开销、旅行基金、教育金" />
        </el-form-item>
        <el-form-item label="初始金额(元)">
          <el-input-number v-model="xiaoheibaoForm.initialBalanceYuan" :min="0" :precision="2" style="width: 100%;" />
        </el-form-item>
        <el-form-item label="共用成员">
          <el-select v-model="xiaoheibaoForm.shared_user_ids" multiple placeholder="选择可共用的成员" style="width: 100%;">
            <el-option v-for="u in familyMembers" :key="u.id" :label="u.nickname" :value="u.id" />
          </el-select>
          <div class="form-tip">选中的成员可以往小荷包存钱和使用里面的钱</div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showXiaoheibaoDialog = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleCreateXiaoheibao">创建</el-button>
      </template>
    </el-dialog>

    <!-- 第二步C：银行账户 -->
    <el-dialog v-model="showBankDialog" title="新建银行账户" width="500px" destroy-on-close>
      <el-form :model="bankForm" label-width="80px">
        <el-form-item label="银行">
          <el-select v-model="bankForm.bank_id" filterable style="width: 100%;" @change="onBankSelect">
            <el-option v-for="b in banks" :key="b.id" :label="b.name" :value="b.id" />
          </el-select>
        </el-form-item>

        <el-form-item label="账户类型">
          <el-radio-group v-model="bankForm.product_type">
            <el-radio-button value="savings">储蓄卡</el-radio-button>
            <el-radio-button value="credit">信用卡</el-radio-button>
            <el-radio-button value="investment">投资理财</el-radio-button>
          </el-radio-group>
        </el-form-item>

        <el-form-item label="卡号后四位" v-if="bankForm.product_type !== 'investment'">
          <el-input v-model="bankForm.card_tail" maxlength="4" placeholder="尾号" />
        </el-form-item>

        <el-form-item label="账户名称">
          <el-input v-model="bankForm.name" :placeholder="bankNamePlaceholder" />
        </el-form-item>

        <template v-if="bankForm.product_type === 'credit'">
          <el-form-item label="信用额度(元)">
            <el-input-number v-model="bankForm.credit_limit_yuan" :min="0" :precision="2" style="width: 100%;" />
          </el-form-item>
          <el-form-item label="账单日">
            <el-input-number v-model="bankForm.billing_day" :min="1" :max="28" />
          </el-form-item>
          <el-form-item label="还款日">
            <el-input-number v-model="bankForm.due_day" :min="1" :max="28" />
          </el-form-item>
        </template>

        <template v-if="bankForm.product_type === 'investment'">
          <el-form-item label="关联储蓄卡">
            <el-select v-model="bankForm.parent_id" style="width: 100%;">
              <el-option v-for="a in savingsAccounts" :key="a.id" :label="a.name" :value="a.id" />
            </el-select>
            <div class="form-tip">当储蓄卡余额不足时，可从此账户扣款</div>
          </el-form-item>
        </template>

        <el-form-item label="初始余额(元)">
          <el-input-number v-model="bankForm.initialBalanceYuan" :precision="2" style="width: 100%;" />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="showBankDialog = false; showCategoryDialog = true">上一步</el-button>
        <el-button type="primary" :loading="saving" @click="handleCreateBankAccount">创建</el-button>
      </template>
    </el-dialog>

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
import { Plus, CircleCheck } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getAccounts, createAccount, updateAccount, deleteAccount } from '@/api/accounts'
import { getBanks, getAccountTemplates } from '@/api/reference'
import { getChannels } from '@/api/channels'
import type { PaymentAccount, Channel } from '@/types'

interface BankItem { id: number; name: string; code: string; short_name: string }
interface TemplateItem { id: number; type_code: string; name: string; icon: string | null; group_name: string; is_credit: boolean }

const loading = ref(false)
const saving = ref(false)
const accounts = ref<PaymentAccount[]>([])
const banks = ref<BankItem[]>([])
const templates = ref<TemplateItem[]>([])
const channels = ref<Channel[]>([])
const familyMembers = ref<{ id: number; nickname: string }[]>([])

const showCategoryDialog = ref(false)
const showChannelDialog = ref(false)
const showProductDialog = ref(false)
const showBankDialog = ref(false)
const showEditDialog = ref(false)
const showFamilyCard = ref(false)
const showXiaoheibaoDialog = ref(false)

const channelForm = reactive({ channel_id: null as number | null, existing_account_id: null as number | null, account_name: '' })
const bankForm = reactive({ bank_id: null as number | null, bank_name: '', product_type: 'savings', card_tail: '', name: '', credit_limit_yuan: 0, billing_day: null as number | null, due_day: null as number | null, initialBalanceYuan: 0, parent_id: null as number | null })
const editForm = reactive({ id: 0, name: '', initialBalanceYuan: 0, notes: '' })
const familyCardForm = reactive({ linked_user_id: null as number | null, linked_account_id: null as number | null, name: '' })
const xiaoheibaoForm = reactive({ name: '', initialBalanceYuan: 0, shared_user_ids: [] as number[] })
const selectedProducts = ref<string[]>([])
const currentChannelId = ref<number | null>(null) // 用于小荷包创建时的渠道ID

const categories = [
  { value: 'channel', icon: '📱', label: '互联网金融', desc: '支付宝/微信/抖音等' },
  { value: 'bank', icon: '🏦', label: '银行卡', desc: '储蓄卡/信用卡/理财' },
  { value: 'other', icon: '💵', label: '其他', desc: '现金/公交卡/饭卡等' },
]

// 支付渠道选项（排除现金、银行转账、POS等）
const channelOptions = computed(() => {
  const excludeNames = ['现金', '银行转账', 'POS刷卡', '其他']
  return channels.value.filter((c) => !excludeNames.includes(c.name))
})

// 根据支付渠道返回对应产品
const channelProducts = computed(() => {
  const channel = channels.value.find((c) => c.id === channelForm.channel_id)
  if (!channel) return []
  const name = channel.name
  if (name.includes('支付宝')) return [
    { type_code: 'alipay_balance', name: '支付宝余额', icon: '💰', desc: '账户余额' },
    { type_code: 'alipay_yuebao', name: '余额宝', icon: '📈', desc: '货币基金' },
    { type_code: 'alipay_huabei', name: '花呗', icon: '🌸', desc: '信用消费' },
    { type_code: 'alipay_jiebei', name: '借呗', icon: '🔶', desc: '信用借款' },
    { type_code: 'alipay_xiaoheibao', name: '小荷包', icon: '👛', desc: '多人共用储蓄，可创建多个' },
  ]
  if (name.includes('微信')) return [
    { type_code: 'wechat_balance', name: '微信零钱', icon: '💰', desc: '账户余额' },
    { type_code: 'wechat_lingqian', name: '零钱通', icon: '📈', desc: '货币基金' },
  ]
  if (name.includes('京东')) return [
    { type_code: 'e_wallet', name: '京东钱包余额', icon: '💰', desc: '账户余额' },
    { type_code: 'jd_baitiao', name: '京东白条', icon: '🏷️', desc: '信用消费' },
  ]
  if (name.includes('抖音')) return [
    { type_code: 'e_wallet', name: '抖音钱包余额', icon: '💰', desc: '账户余额' },
  ]
  // 云闪付、美团支付等
  return [{ type_code: 'e_wallet', name: `${name}余额`, icon: '💰', desc: '账户余额' }]
})

// 已有的该渠道账户（顶级）
const existingChannelAccounts = computed(() => {
  if (!channelForm.channel_id) return []
  return accounts.value.filter((a) => a.channel_id === channelForm.channel_id && a.is_active && !a.parent_id)
})

const allAccounts = computed(() => accounts.value.filter((a) => a.is_active))
const savingsAccounts = computed(() => accounts.value.filter((a) => a.type_code === 'bank_savings' && a.is_active))

// 账户分组
const accountGroups = computed(() => {
  const groups: Record<string, { icon: string; label: string; accounts: PaymentAccount[] }> = {}
  for (const a of accounts.value) {
    if (!a.is_active || a.is_hidden) continue
    let key: string, icon: string, label: string
    if (a.channel_id) {
      const c = channels.value.find((c) => c.id === a.channel_id)
      key = `ch_${a.channel_id}`
      icon = c?.name.includes('支付宝') ? '📱' : c?.name.includes('微信') ? '💬' : '🌐'
      label = c?.name || '支付渠道'
    } else if (a.bank_id) {
      const b = banks.value.find((b) => b.id === a.bank_id)
      key = `bank_${a.bank_id}`; icon = '🏦'; label = b?.name || '银行'
    } else {
      key = 'other'; icon = '💵'; label = '其他'
    }
    if (!groups[key]) groups[key] = { icon, label, accounts: [] }
    groups[key].accounts.push(a)
  }
  return Object.values(groups)
})

const bankNamePlaceholder = computed(() => {
  const bank = banks.value.find((b) => b.id === bankForm.bank_id)
  const n = bank?.name || '银行'
  return bankForm.product_type === 'savings' ? `${n}储蓄卡` : bankForm.product_type === 'credit' ? `${n}信用卡` : `${n}投资`
})

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }
function getTemplateName(typeCode: string) { return templates.value.find((t) => t.type_code === typeCode)?.name || typeCode }
function getChannelName(id: number | null) { return channels.value.find((c) => c.id === id)?.name || '渠道' }

function openCreate() { showCategoryDialog.value = true }

function openAddProduct(group: { label: string }) {
  const channel = channels.value.find((c) => c.name === group.label)
  if (channel) {
    channelForm.channel_id = channel.id; channelForm.existing_account_id = null; channelForm.account_name = ''
    showChannelDialog.value = true
  }
}

function selectCategory(cat: string) {
  showCategoryDialog.value = false
  if (cat === 'channel') { channelForm.channel_id = null; channelForm.existing_account_id = null; showChannelDialog.value = true }
  else if (cat === 'bank') { resetBankForm(); showBankDialog.value = true }
  else { resetBankForm(); bankForm.product_type = 'cash'; showBankDialog.value = true }
}

function onChannelSelect() { channelForm.existing_account_id = null; channelForm.account_name = '' }

function goToProductSelect() {
  if (!channelForm.channel_id) { ElMessage.warning('请选择支付渠道'); return }
  showChannelDialog.value = false; selectedProducts.value = []; showFamilyCard.value = false; showProductDialog.value = true
}

function toggleProduct(code: string) {
  // 小荷包特殊处理：点击后直接打开创建对话框
  if (code === 'alipay_xiaoheibao') {
    currentChannelId.value = channelForm.channel_id
    xiaoheibaoForm.name = ''
    xiaoheibaoForm.initialBalanceYuan = 0
    xiaoheibaoForm.shared_user_ids = []
    showXiaoheibaoDialog.value = true
    return
  }
  const i = selectedProducts.value.indexOf(code)
  i >= 0 ? selectedProducts.value.splice(i, 1) : selectedProducts.value.push(code)
}

async function handleCreateXiaoheibao() {
  if (!xiaoheibaoForm.name) { ElMessage.warning('请填写小荷包名称'); return }
  saving.value = true
  try {
    const cid = currentChannelId.value!
    const cname = '支付宝'
    // 获取或创建支付宝主账号
    let parentId = existingChannelAccounts.value.find((a) => !a.parent_id)?.id
    if (!parentId) {
      const res = await createAccount({ name: '我的支付宝', type_code: 'e_wallet', channel_id: cid, group_label: cname } as any)
      parentId = res.data.id
    }
    await createAccount({
      name: `小荷包-${xiaoheibaoForm.name}`,
      type_code: 'alipay_xiaoheibao',
      channel_id: cid,
      parent_id: parentId,
      group_label: cname,
      is_shared: xiaoheibaoForm.shared_user_ids.length > 0,
      initial_balance: Math.round(xiaoheibaoForm.initialBalanceYuan * 100),
    } as any)
    ElMessage.success('小荷包创建成功')
    showXiaoheibaoDialog.value = false
    await load()
  } catch (e: unknown) { ElMessage.error((e as any)?.response?.data?.detail || '创建失败') }
  finally { saving.value = false }
}

function onBankSelect() {
  const b = banks.value.find((b) => b.id === bankForm.bank_id)
  if (b) { bankForm.bank_name = b.name; bankForm.name = bankNamePlaceholder.value }
}

function resetBankForm() {
  bankForm.bank_id = null; bankForm.bank_name = ''; bankForm.product_type = 'savings'
  bankForm.card_tail = ''; bankForm.name = ''; bankForm.credit_limit_yuan = 0
  bankForm.billing_day = null; bankForm.due_day = null; bankForm.initialBalanceYuan = 0; bankForm.parent_id = null
}

async function handleCreateChannelAccounts() {
  if (!selectedProducts.value.length && !showFamilyCard.value) { ElMessage.warning('请至少选择一个产品'); return }
  saving.value = true
  try {
    const cid = channelForm.channel_id!
    const cname = channels.value.find((c) => c.id === cid)?.name || '渠道'
    let parentId = channelForm.existing_account_id
    if (!parentId) {
      const res = await createAccount({ name: channelForm.account_name || `我的${cname}`, type_code: 'e_wallet', channel_id: cid, group_label: cname } as any)
      parentId = res.data.id
    }
    for (const code of selectedProducts.value) {
      const t = templates.value.find((t) => t.type_code === code)
      await createAccount({ name: t?.name || code, type_code: code, channel_id: cid, parent_id: parentId, group_label: cname } as any)
    }
    if (showFamilyCard.value && familyCardForm.name && familyCardForm.linked_account_id) {
      await createAccount({ name: familyCardForm.name, type_code: 'e_wallet', channel_id: cid, linked_account_id: familyCardForm.linked_account_id, linked_user_id: familyCardForm.linked_user_id, group_label: cname } as any)
    }
    ElMessage.success('创建成功'); showProductDialog.value = false; await load()
  } catch (e: unknown) { ElMessage.error((e as any)?.response?.data?.detail || '创建失败') }
  finally { saving.value = false }
}

async function handleCreateBankAccount() {
  if (!bankForm.bank_id || !bankForm.name) { ElMessage.warning('请选择银行并填写名称'); return }
  saving.value = true
  try {
    const typeMap: Record<string, string> = { savings: 'bank_savings', credit: 'bank_credit', investment: 'fund_account', cash: 'cash' }
    const payload: Record<string, unknown> = { name: bankForm.name, type_code: typeMap[bankForm.product_type], bank_id: bankForm.bank_id, bank_name: bankForm.bank_name, initial_balance: Math.round(bankForm.initialBalanceYuan * 100) }
    if (bankForm.card_tail) payload.card_tail = bankForm.card_tail
    if (bankForm.product_type === 'credit') { payload.credit_limit = Math.round(bankForm.credit_limit_yuan * 100); if (bankForm.billing_day) payload.billing_day = bankForm.billing_day; if (bankForm.due_day) payload.due_day = bankForm.due_day }
    if (bankForm.parent_id) payload.parent_id = bankForm.parent_id
    await createAccount(payload as any); ElMessage.success('创建成功'); showBankDialog.value = false; await load()
  } catch (e: unknown) { ElMessage.error((e as any)?.response?.data?.detail || '创建失败') }
  finally { saving.value = false }
}

function editAccount(row: PaymentAccount) { editForm.id = row.id; editForm.name = row.name; editForm.initialBalanceYuan = row.initial_balance / 100; editForm.notes = ''; showEditDialog.value = true }

async function handleUpdate() {
  if (!editForm.name) { ElMessage.warning('请填写名称'); return }
  saving.value = true
  try { await updateAccount(editForm.id, { name: editForm.name, initial_balance: Math.round(editForm.initialBalanceYuan * 100), notes: editForm.notes || undefined } as any); ElMessage.success('更新成功'); showEditDialog.value = false; await load() }
  catch { ElMessage.error('更新失败') } finally { saving.value = false }
}

async function handleArchive(id: number) { try { await deleteAccount(id); ElMessage.success('已归档'); await load() } catch { ElMessage.error('操作失败') } }

async function load() { loading.value = true; try { accounts.value = (await getAccounts(true)).data } finally { loading.value = false } }

onMounted(async () => {
  await Promise.all([load(), getBanks().then((r) => { banks.value = r.data }), getAccountTemplates().then((r) => { templates.value = r.data }), getChannels().then((r) => { channels.value = r.data })])
})
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
.form-tip { font-size: 12px; color: #909399; margin-top: 4px; }
.text-expense { color: #f56c6c; }
.selected-card { border-color: #67c23a; background-color: #f0f9eb; }
</style>
