<template>
  <el-dialog v-model="visible" :title="title" width="550px" destroy-on-close @close="$emit('close')">
    <!-- 第一步：选择类别 -->
    <div v-if="step === 1" style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px;">
      <el-card v-for="cat in categories" :key="cat.value" shadow="hover" style="cursor: pointer; text-align: center;"
        @click="selectCategory(cat.value)">
        <div style="font-size: 36px; margin-bottom: 8px;">{{ cat.icon }}</div>
        <div style="font-weight: 500;">{{ cat.label }}</div>
        <div style="font-size: 12px; color: #909399; margin-top: 4px;">{{ cat.desc }}</div>
      </el-card>
    </div>

    <!-- 第二步A：选择支付渠道 -->
    <div v-if="step === 2 && categoryType === 'channel'">
      <el-form label-width="80px">
        <el-form-item label="支付渠道">
          <el-select v-model="form.channel_id" style="width: 100%;" @change="onChannelChange">
            <el-option v-for="c in channelOptions" :key="c.id" :label="c.name" :value="c.id" />
          </el-select>
        </el-form-item>

        <!-- 选择已有账号或新建 -->
        <el-form-item label="账号" v-if="existingPlatformAccounts.length > 0">
          <el-radio-group v-model="form.existing_parent_id" style="width: 100%;">
            <el-radio v-for="a in existingPlatformAccounts" :key="a.id" :value="a.id" style="display: block; margin-bottom: 8px;">
              {{ a.name }}
            </el-radio>
            <el-radio :value="null" style="display: block;">新建账号</el-radio>
          </el-radio-group>
        </el-form-item>

        <!-- 新建账号时显示 -->
        <template v-if="!form.existing_parent_id">
          <el-form-item label="账号标识">
            <el-input v-model="form.account_identifier" placeholder="手机号/邮箱/昵称（用于区分多个账号）" />
          </el-form-item>
          <el-form-item label="账号名称">
            <el-input v-model="form.parent_name" :placeholder="parentNamePlaceholder" />
          </el-form-item>
        </template>

        <el-form-item label="产品类型">
          <el-select v-model="form.type_code" style="width: 100%;" @change="onProductChange">
            <el-option v-for="p in channelProducts" :key="p.type_code" :label="`${p.icon} ${p.name}`" :value="p.type_code" />
          </el-select>
        </el-form-item>
        <el-form-item label="产品名称">
          <el-input v-model="form.name" placeholder="如：花呗、余额宝" />
        </el-form-item>
        <!-- 信用类产品显示额度/账单日/还款日 -->
        <template v-if="isChannelCredit">
          <el-form-item label="信用额度(元)"><el-input-number v-model="form.credit_limit_yuan" :min="0" :precision="2" style="width: 100%;" /></el-form-item>
          <el-form-item label="账单日">
            <el-select v-model="form.billing_day" clearable placeholder="每月几号" style="width: 100%;">
              <el-option v-for="d in dayOptions" :key="d" :label="`每月 ${d} 号`" :value="d" />
            </el-select>
          </el-form-item>
          <el-form-item label="还款日">
            <el-select v-model="form.due_day" clearable placeholder="每月几号" style="width: 100%;">
              <el-option v-for="d in dayOptions" :key="d" :label="`每月 ${d} 号`" :value="d" />
            </el-select>
          </el-form-item>
        </template>
      </el-form>
    </div>

    <!-- 第二步B：银行账户 -->
    <div v-if="step === 2 && categoryType === 'bank'">
      <el-form label-width="80px">
        <el-form-item label="银行">
          <el-select v-model="form.bank_id" filterable style="width: 100%;" @change="onBankChange">
            <el-option v-for="b in banks" :key="b.id" :label="b.name" :value="b.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="账户类型">
          <el-radio-group v-model="form.bank_type" @change="onBankTypeChange">
            <el-radio-button value="savings">储蓄卡</el-radio-button>
            <el-radio-button value="credit">信用卡</el-radio-button>
            <el-radio-button value="investment">投资理财</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="卡号后四位" v-if="form.bank_type !== 'investment'">
          <el-input v-model="form.card_tail" maxlength="4" placeholder="0000" @input="form.card_tail = form.card_tail.replace(/\D/g, '')" />
        </el-form-item>
        <el-form-item label="账户名称">
          <el-input v-model="form.name" :placeholder="bankNamePlaceholder" />
        </el-form-item>
        <template v-if="form.bank_type === 'credit'">
          <el-form-item label="信用额度(元)"><el-input-number v-model="form.credit_limit_yuan" :min="0" :precision="2" style="width: 100%;" /></el-form-item>
          <el-form-item label="账单日">
            <el-select v-model="form.billing_day" clearable placeholder="每月几号" style="width: 100%;">
              <el-option v-for="d in dayOptions" :key="d" :label="`每月 ${d} 号`" :value="d" />
            </el-select>
          </el-form-item>
          <el-form-item label="还款日">
            <el-select v-model="form.due_day" clearable placeholder="每月几号" style="width: 100%;">
              <el-option v-for="d in dayOptions" :key="d" :label="`每月 ${d} 号`" :value="d" />
            </el-select>
          </el-form-item>
        </template>
        <template v-if="form.bank_type === 'investment'">
          <el-form-item label="关联储蓄卡">
            <el-select v-model="form.parent_id" clearable placeholder="可选，不关联则独立显示" style="width: 100%;">
              <el-option v-for="a in savingsAccounts" :key="a.id" :label="a.name" :value="a.id" />
            </el-select>
            <div v-if="savingsAccounts.length === 0" style="color: #e6a23c; font-size: 12px; margin-top: 4px;">
              暂无储蓄卡，请先创建
            </div>
          </el-form-item>
        </template>
      </el-form>
    </div>

    <!-- 第二步C：其他 -->
    <div v-if="step === 2 && categoryType === 'other'">
      <el-form label-width="80px">
        <el-form-item label="类型">
          <el-select v-model="form.type_code" style="width: 100%;">
            <el-option label="现金" value="cash" />
            <el-option label="公交卡" value="bus_card" />
            <el-option label="饭卡" value="meal_card" />
            <el-option label="会员卡" value="membership_card" />
            <el-option label="其他" value="e_wallet" />
          </el-select>
        </el-form-item>
        <el-form-item label="账户名称">
          <el-input v-model="form.name" />
        </el-form-item>
      </el-form>
    </div>

    <template #footer>
      <el-button @click="visible = false">取消</el-button>
      <el-button v-if="step === 2" @click="step = 1">上一步</el-button>
      <el-button v-if="step === 1" type="primary" disabled>请选择类别</el-button>
      <el-button v-if="step === 2" type="primary" :loading="saving" @click="handleCreate">创建</el-button>
    </template>
  </el-dialog>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, nextTick } from 'vue'
import { ElMessage } from 'element-plus'
import { createAccount } from '@/api/accounts'
import type { PaymentAccount, Channel } from '@/types'

interface BankItem { id: number; name: string; code: string; short_name: string }

const props = defineProps<{
  modelValue: boolean
  banks: BankItem[]
  channels: Channel[]
  accounts: PaymentAccount[]
  initialMethod?: string  // 从导入传入的支付方式，如"工商银行储蓄卡（0726）"
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'close'): void
  (e: 'created', account: PaymentAccount): void
}>()

const visible = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v),
})

const title = computed(() => step.value === 1 ? '新建账户' : '填写账户信息')

const step = ref(1)
const saving = ref(false)
const categoryType = ref<'channel' | 'bank' | 'other'>('channel')

const categories = [
  { value: 'channel', icon: '📱', label: '互联网金融', desc: '支付宝/微信/抖音等' },
  { value: 'bank', icon: '🏦', label: '银行卡', desc: '储蓄卡/信用卡/理财' },
  { value: 'other', icon: '💵', label: '其他', desc: '现金/公交卡/饭卡等' },
]

const form = reactive({
  channel_id: null as number | null,
  bank_id: null as number | null,
  bank_name: '',
  type_code: '',
  name: '',
  card_tail: '',
  bank_type: 'savings',
  credit_limit_yuan: 0,
  billing_day: null as number | null,
  due_day: null as number | null,
  parent_id: null as number | null,
  existing_parent_id: null as number | null,
  account_identifier: '',
  parent_name: '',
})

// 支付渠道选项
const channelOptions = computed(() => {
  const excludeNames = ['现金', '银行转账', 'POS刷卡', '其他']
  return props.channels.filter((c) => !excludeNames.includes(c.name))
})

// 已有的该渠道顶级账户
const existingPlatformAccounts = computed(() => {
  if (!form.channel_id) return []
  return props.accounts.filter((a) => a.channel_id === form.channel_id && !a.parent_id && a.is_active)
})

// 父账户名称占位符
const parentNamePlaceholder = computed(() => {
  const channel = props.channels.find((c) => c.id === form.channel_id)
  if (!channel) return '账号名称'
  const identifier = form.account_identifier ? `-${form.account_identifier}` : ''
  return `我的${channel.name}${identifier}`
})

// 根据渠道返回产品列表
const channelProducts = computed(() => {
  const channel = props.channels.find((c) => c.id === form.channel_id)
  if (!channel) return []
  const name = channel.name
  if (name.includes('支付宝')) return [
    { type_code: 'alipay_balance', name: '支付宝余额', icon: '💰' },
    { type_code: 'alipay_yuebao', name: '余额宝', icon: '📈' },
    { type_code: 'alipay_huabei', name: '花呗', icon: '🌸' },
    { type_code: 'alipay_jiebei', name: '借呗', icon: '🔶' },
    { type_code: 'alipay_xiaoheibao', name: '小荷包', icon: '👛' },
  ]
  if (name.includes('微信')) return [
    { type_code: 'wechat_balance', name: '微信零钱', icon: '💰' },
    { type_code: 'wechat_lingqian', name: '零钱通', icon: '📈' },
  ]
  if (name.includes('京东')) return [
    { type_code: 'e_wallet', name: '京东钱包余额', icon: '💰' },
    { type_code: 'jd_baitiao', name: '京东白条', icon: '🏷️' },
  ]
  if (name.includes('抖音')) return [
    { type_code: 'e_wallet', name: '抖音钱包余额', icon: '💰' },
  ]
  return [{ type_code: 'e_wallet', name: `${name}余额`, icon: '💰' }]
})

const savingsAccounts = computed(() => props.accounts.filter((a) => a.type_code === 'bank_savings' && a.is_active))

// 日期选项 1-28
const dayOptions = Array.from({ length: 28 }, (_, i) => i + 1)

// 当前渠道产品是否为信用类
const creditTypeCodes = new Set(['alipay_huabei', 'alipay_jiebei', 'jd_baitiao'])
const isChannelCredit = computed(() => creditTypeCodes.has(form.type_code))

// 银行卡名称占位符
const bankNamePlaceholder = computed(() => {
  const bank = props.banks.find((b) => b.id === form.bank_id)
  const bankName = bank?.name || '银行'
  const typeMap: Record<string, string> = { savings: '储蓄卡', credit: '信用卡', investment: '投资' }
  const tail = form.card_tail ? `(尾号${form.card_tail})` : ''
  return `${bankName}${typeMap[form.bank_type] || ''}${tail}`
})

function selectCategory(cat: string) {
  categoryType.value = cat as 'channel' | 'bank' | 'other'
  step.value = 2
  resetForm()
}

function resetForm() {
  form.channel_id = null
  form.bank_id = null
  form.bank_name = ''
  form.type_code = ''
  form.name = ''
  form.card_tail = ''
  form.bank_type = 'savings'
  form.credit_limit_yuan = 0
  form.billing_day = null
  form.due_day = null
  form.parent_id = null
  form.existing_parent_id = null
  form.account_identifier = ''
  form.parent_name = ''
}

function onChannelChange() {
  form.existing_parent_id = null
  form.account_identifier = ''
  form.parent_name = ''
  form.credit_limit_yuan = 0
  form.billing_day = null
  form.due_day = null
  if (channelProducts.value.length > 0) {
    form.type_code = channelProducts.value[0].type_code
    form.name = channelProducts.value[0].name
  }
}

function onProductChange(typeCode: string) {
  const product = channelProducts.value.find((p) => p.type_code === typeCode)
  if (product) form.name = product.name
  // 重置信用字段
  form.credit_limit_yuan = 0
  form.billing_day = null
  form.due_day = null
}

function onBankChange() {
  const bank = props.banks.find((b) => b.id === form.bank_id)
  if (bank) {
    form.bank_name = bank.name
    const typeMap: Record<string, string> = { savings: '储蓄卡', credit: '信用卡', investment: '投资' }
    form.name = `${bank.name}${typeMap[form.bank_type] || '储蓄卡'}`
  }
}

function onBankTypeChange(bankType: string) {
  const bank = props.banks.find((b) => b.id === form.bank_id)
  if (bank) {
    const typeMap: Record<string, string> = { savings: '储蓄卡', credit: '信用卡', investment: '投资' }
    const tail = form.card_tail ? `(尾号${form.card_tail})` : ''
    form.name = `${bank.name}${typeMap[bankType] || '储蓄卡'}${tail}`
  }
}

async function handleCreate() {
  if (!form.name) { ElMessage.warning('请填写账户名称'); return }
  saving.value = true
  try {
    let parentId = form.existing_parent_id

    // 如果是新建平台账号，先创建父账户
    if (categoryType.value === 'channel' && !parentId) {
      const channel = props.channels.find((c) => c.id === form.channel_id)
      const parentName = form.parent_name || `我的${channel?.name || '平台'}${form.account_identifier ? `-${form.account_identifier}` : ''}`
      const parentRes = await createAccount({
        name: parentName,
        type_code: 'e_wallet',
        channel_id: form.channel_id,
      } as any)
      parentId = parentRes.data.id
    }

    const payload: Record<string, unknown> = {
      name: form.name,
      type_code: form.type_code || 'e_wallet',
    }

    if (categoryType.value === 'channel') {
      payload.channel_id = form.channel_id
      if (parentId) payload.parent_id = parentId
      // 渠道信用类产品（花呗、借呗、白条）
      if (isChannelCredit.value) {
        payload.credit_limit = Math.round((form.credit_limit_yuan || 0) * 100)
        if (form.billing_day) payload.billing_day = form.billing_day
        if (form.due_day) payload.due_day = form.due_day
      }
    } else if (categoryType.value === 'bank') {
      payload.bank_id = form.bank_id
      payload.bank_name = form.bank_name
      if (form.card_tail) payload.card_tail = form.card_tail
      if (form.bank_type === 'savings') {
        payload.type_code = 'bank_savings'
      } else if (form.bank_type === 'credit') {
        payload.type_code = 'bank_credit'
        payload.credit_limit = Math.round((form.credit_limit_yuan || 0) * 100)
        if (form.billing_day) payload.billing_day = form.billing_day
        if (form.due_day) payload.due_day = form.due_day
      } else if (form.bank_type === 'investment') {
        payload.type_code = 'fund_account'
        if (form.parent_id) payload.parent_id = form.parent_id
      }
    }

    const res = await createAccount(payload as any)
    ElMessage.success('账户创建成功')
    emit('created', res.data)
    visible.value = false
  } catch (err: unknown) {
    ElMessage.error((err as any)?.response?.data?.detail || '创建失败')
  } finally {
    saving.value = false
  }
}

function parseMethodString(method: string) {
  // 解析 "工商银行储蓄卡（0726）" → { bank: "工商银行", type: "savings", tail: "0726" }
  const tailMatch = method.match(/[（(](\d{4})[）)]/)
  const tail = tailMatch ? tailMatch[1] : ''

  let bankType = 'savings'
  if (method.includes('信用卡')) bankType = 'credit'
  else if (method.includes('投资') || method.includes('理财')) bankType = 'investment'

  // 提取银行名：去掉类型词和尾号
  let bankName = method
    .replace(/储蓄卡|信用卡|投资|理财/g, '')
    .replace(/[（(]\d{4}[）)]/, '')
    .trim()

  // 尝试匹配已知银行（精确匹配优先，然后前缀匹配）
  const matchedBank = props.banks.find((b) =>
    bankName === b.name || bankName === b.short_name
  ) || props.banks.find((b) =>
    bankName.includes(b.name) || b.name.includes(bankName) ||
    (b.short_name && (bankName.includes(b.short_name) || b.short_name.includes(bankName)))
  )

  return { bankName, bankType, tail, matchedBank }
}

// 尝试填充银行信息（banks 加载后可能需要重试）
function tryFillFromMethod() {
  if (!props.initialMethod || categoryType.value !== 'bank') return
  const parsed = parseMethodString(props.initialMethod)
  if (parsed.matchedBank && !form.bank_id) {
    form.bank_id = parsed.matchedBank.id
    form.bank_name = parsed.matchedBank.name
    form.bank_type = parsed.bankType
    form.card_tail = parsed.tail
    const typeMap: Record<string, string> = { savings: '储蓄卡', credit: '信用卡', investment: '投资' }
    form.name = `${parsed.matchedBank.name}${typeMap[parsed.bankType] || '储蓄卡'}${parsed.tail ? `(尾号${parsed.tail})` : ''}`
  }
}

watch(visible, (v) => {
  if (v) {
    step.value = 1
    categoryType.value = 'channel'
    resetForm()

    // 如果传入了 initialMethod，自动填充银行信息
    if (props.initialMethod) {
      categoryType.value = 'bank'
      step.value = 2
      // 尝试立即填充
      nextTick(() => { tryFillFromMethod() })
    }
  }
})

// banks 加载后重试填充（immediate 确保首次加载也触发）
watch(() => props.banks, (newBanks) => {
  if (newBanks && newBanks.length > 0) {
    tryFillFromMethod()
  }
}, { deep: true, immediate: true })
</script>
