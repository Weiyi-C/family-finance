<template>
  <div>
    <div class="page-header">
      <h3>记账</h3>
      <el-button type="primary" @click="openCreate">
        <el-icon><Plus /></el-icon> 记一笔
      </el-button>
    </div>

    <el-card class="filter-card">
      <el-form :inline="true" :model="filters">
        <el-form-item label="账本">
          <el-select v-model="filters.book_id" clearable placeholder="全部" style="width: 120px;" @change="loadTransactions">
            <el-option v-for="b in books" :key="b.id" :label="b.name" :value="b.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="类型">
          <el-select v-model="filters.type" clearable placeholder="全部" style="width: 100px;">
            <el-option label="支出" value="expense" />
            <el-option label="收入" value="income" />
            <el-option label="转账" value="transfer" />
          </el-select>
        </el-form-item>
        <el-form-item label="日期">
          <el-date-picker v-model="dateRange" type="daterange" start-placeholder="开始" end-placeholder="结束"
            value-format="YYYY-MM-DD" @change="onDateChange" style="width: 260px;" />
        </el-form-item>
        <el-form-item label="账户">
          <el-select v-model="filters.payment_account_id" clearable placeholder="全部" style="width: 120px;">
            <el-option v-for="a in accounts" :key="a.id" :label="a.name" :value="a.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="渠道">
          <el-select v-model="filters.payment_channel_id" clearable placeholder="全部" style="width: 100px;">
            <el-option v-for="c in channels" :key="c.id" :label="c.name" :value="c.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="平台">
          <el-select v-model="filters.platform_id" clearable placeholder="全部" style="width: 100px;">
            <el-option v-for="p in platforms" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="关键词">
          <el-input v-model="filters.keyword" placeholder="搜索备注/商户" clearable style="width: 140px;" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="loadTransactions">查询</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card style="margin-top: 16px;">
      <el-table :data="transactions" stripe v-loading="loading" style="width: 100%;">
        <el-table-column prop="transaction_time" label="时间" width="160" fixed>
          <template #default="{ row }">{{ formatTime(row.transaction_time) }}</template>
        </el-table-column>
        <el-table-column label="账本" width="80">
          <template #default="{ row }">{{ getBookName(row.book_id) }}</template>
        </el-table-column>
        <el-table-column prop="type" label="类型" width="70">
          <template #default="{ row }">
            <el-tag :type="typeTag[row.type]" size="small">{{ typeMap[row.type] }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="分类" width="120">
          <template #default="{ row }">
            <span v-if="row.category_id">{{ getCategoryPath(row.category_id, row.sub_category_id) }}</span>
            <span v-else style="color: #c0c4cc;">未分类</span>
          </template>
        </el-table-column>
        <el-table-column prop="merchant_name" label="商户" width="120" show-overflow-tooltip />
        <el-table-column label="资金来源" width="100">
          <template #default="{ row }">
            <span v-if="row.payment_account_id">{{ getAccountName(row.payment_account_id) }}</span>
            <span v-else style="color: #c0c4cc;">-</span>
          </template>
        </el-table-column>
        <el-table-column label="支付渠道" width="90">
          <template #default="{ row }">
            <span v-if="row.payment_channel_id">{{ getChannelName(row.payment_channel_id) }}</span>
            <span v-else style="color: #c0c4cc;">-</span>
          </template>
        </el-table-column>
        <el-table-column label="平台" width="80">
          <template #default="{ row }">
            <span v-if="row.platform_id">{{ getPlatformName(row.platform_id) }}</span>
            <span v-else style="color: #c0c4cc;">-</span>
          </template>
        </el-table-column>
        <el-table-column label="币种" width="60">
          <template #default="{ row }">{{ row.currency || 'CNY' }}</template>
        </el-table-column>
        <el-table-column prop="description" label="备注" min-width="120" show-overflow-tooltip />
        <el-table-column label="标签" width="120">
          <template #default="{ row }">
            <el-tag v-for="tagId in (row.tag_ids || [])" :key="tagId" size="small" style="margin-right: 4px;">
              {{ getTagName(tagId) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="amount" label="金额" align="right" width="110" fixed="right">
          <template #default="{ row }">
            <span :class="row.type === 'expense' ? 'text-expense' : 'text-income'">
              {{ row.type === 'expense' ? '-' : '+' }}{{ formatMoney(row.amount) }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="editTxn(row)">编辑</el-button>
            <el-popconfirm title="确定删除？" @confirm="handleDelete(row.id)">
              <template #reference>
                <el-button link type="danger" size="small">删除</el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
      <div class="pagination">
        <el-pagination
          v-model:current-page="page"
          :page-size="pageSize"
          :total="total"
          layout="prev, pager, next, total"
          @current-change="loadTransactions"
        />
      </div>
    </el-card>

    <!-- 新建/编辑对话框 -->
    <el-dialog v-model="showCreateDialog" :title="editingId ? '编辑交易' : '记一笔'" width="650px" destroy-on-close>
      <el-form :model="form" label-width="80px">
        <el-row :gutter="16">
          <el-col :span="12">
            <el-form-item label="类型">
              <el-radio-group v-model="form.type">
                <el-radio-button value="expense">支出</el-radio-button>
                <el-radio-button value="income">收入</el-radio-button>
                <el-radio-button value="transfer">转账</el-radio-button>
              </el-radio-group>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="币种">
              <el-select v-model="form.currency" style="width: 100%;">
                <el-option label="人民币 CNY" value="CNY" />
                <el-option label="美元 USD" value="USD" />
                <el-option label="欧元 EUR" value="EUR" />
                <el-option label="日元 JPY" value="JPY" />
                <el-option label="港币 HKD" value="HKD" />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>

        <el-row :gutter="16">
          <el-col :span="12">
            <el-form-item label="金额">
              <el-input-number v-model="form.amountYuan" :min="0.01" :precision="2" style="width: 100%;" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="时间">
              <el-date-picker v-model="form.transaction_time" type="datetime" value-format="YYYY-MM-DDTHH:mm:ss"
                style="width: 100%;" />
            </el-form-item>
          </el-col>
        </el-row>

        <!-- 三级分类选择 -->
        <el-form-item label="分类">
          <el-cascader
            v-model="categoryPath"
            :options="categoryTree"
            :props="{ value: 'id', label: 'name', children: 'children', checkStrictly: true }"
            clearable
            filterable
            placeholder="选择分类"
            style="width: 100%;"
            @change="onCategoryChange"
          />
        </el-form-item>

        <el-row :gutter="16">
          <el-col :span="12">
            <el-form-item label="资金来源">
              <el-select v-model="form.payment_account_id" clearable filterable placeholder="选择账户" style="width: 100%;">
                <el-option v-for="a in accounts" :key="a.id" :label="a.name" :value="a.id" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="支付渠道">
              <el-select v-model="form.payment_channel_id" clearable filterable placeholder="选择渠道" style="width: 100%;">
                <el-option v-for="c in channels" :key="c.id" :label="c.name" :value="c.id" />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>

        <el-row :gutter="16">
          <el-col :span="12">
            <el-form-item label="交易平台">
              <el-select v-model="form.platform_id" clearable filterable placeholder="选择平台" style="width: 100%;">
                <el-option v-for="p in platforms" :key="p.id" :label="p.name" :value="p.id" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="付款人">
              <el-select v-model="form.paid_by" clearable filterable placeholder="选择付款人" style="width: 100%;">
                <el-option v-for="m in familyMembers" :key="m.id" :label="m.nickname" :value="m.id" />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>

        <el-form-item label="商户">
          <el-input v-model="form.merchant_name" placeholder="商户名称" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="form.description" type="textarea" :rows="2" />
        </el-form-item>
        <el-form-item label="标签">
          <el-select v-model="form.tag_ids" multiple clearable placeholder="选择标签" style="width: 100%;">
            <el-option v-for="t in tags" :key="t.id" :label="t.name" :value="t.id" />
          </el-select>
        </el-form-item>

        <!-- 外币信息（仅非CNY时显示） -->
        <template v-if="form.currency !== 'CNY'">
          <el-divider>外币信息</el-divider>
          <el-row :gutter="16">
            <el-col :span="8">
              <el-form-item label="原币金额">
                <el-input-number v-model="form.originalAmountYuan" :min="0.01" :precision="2" style="width: 100%;" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="原币种">
                <el-input v-model="form.original_currency" disabled />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="汇率">
                <el-input-number v-model="form.exchange_rate" :min="0.000001" :precision="6" style="width: 100%;" />
              </el-form-item>
            </el-col>
          </el-row>
        </template>
      </el-form>
      <template #footer>
        <el-button @click="showCreateDialog = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Plus } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getTransactions, createTransaction, updateTransaction, deleteTransaction } from '@/api/transactions'
import { getCategories } from '@/api/categories'
import { getAccounts } from '@/api/accounts'
import { getChannels, getPlatforms } from '@/api/channels'
import { getTags } from '@/api/tags'
import { getBooks } from '@/api/books'
import type { Transaction, Category, PaymentAccount, Tag, Channel, Platform, AccountBook } from '@/types'

interface FamilyMember { id: number; nickname: string }

const loading = ref(false)
const saving = ref(false)
const transactions = ref<Transaction[]>([])
const categoryTree = ref<Category[]>([])
const categoriesFlat = ref<Category[]>([])
const accounts = ref<PaymentAccount[]>([])
const channels = ref<Channel[]>([])
const platforms = ref<Platform[]>([])
const tags = ref<Tag[]>([])
const books = ref<AccountBook[]>([])
const familyMembers = ref<FamilyMember[]>([])
const page = ref(1)
const pageSize = 20
const total = ref(0)
const dateRange = ref<[string, string] | null>(null)
const showCreateDialog = ref(false)
const editingId = ref<number | null>(null)
const categoryPath = ref<number[]>([])

const typeMap: Record<string, string> = { expense: '支出', income: '收入', transfer: '转账' }
const typeTag: Record<string, string> = { expense: 'danger', income: 'success', transfer: 'info' }

const filters = reactive({
  book_id: null as number | null,
  type: '', keyword: '', start_date: '', end_date: '',
  payment_account_id: null as number | null,
  payment_channel_id: null as number | null,
  platform_id: null as number | null,
})

const form = reactive({
  type: 'expense',
  amountYuan: 0,
  transaction_time: '',
  currency: 'CNY',
  category_id: null as number | null,
  sub_category_id: null as number | null,
  detail_category_id: null as number | null,
  payment_account_id: null as number | null,
  payment_channel_id: null as number | null,
  platform_id: null as number | null,
  paid_by: null as number | null,
  merchant_name: '',
  description: '',
  tag_ids: [] as number[],
  book_id: 1,
  originalAmountYuan: 0,
  original_currency: '',
  exchange_rate: 1,
})

// 名称查找函数
function getCategoryName(id: number) {
  return categoriesFlat.value.find((c) => c.id === id)?.name || `分类${id}`
}
function getCategoryPath(catId: number | null, subCatId: number | null) {
  if (!catId) return '未分类'
  const cat = getCategoryName(catId)
  if (subCatId) return `${cat} > ${getCategoryName(subCatId)}`
  return cat
}
function getAccountName(id: number) {
  return accounts.value.find((a) => a.id === id)?.name || `账户${id}`
}
function getChannelName(id: number) {
  return channels.value.find((c) => c.id === id)?.name || `渠道${id}`
}
function getPlatformName(id: number) {
  return platforms.value.find((p) => p.id === id)?.name || `平台${id}`
}
function getTagName(id: number) {
  return tags.value.find((t) => t.id === id)?.name || `标签${id}`
}
function getBookName(id: number) {
  return books.value.find((b) => b.id === id)?.name || `账本${id}`
}

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }
function formatTime(t: string) { return t ? new Date(t).toLocaleString('zh-CN') : '' }
function onDateChange(val: [string, string] | null) {
  filters.start_date = val?.[0] || ''
  filters.end_date = val?.[1] || ''
}

function onCategoryChange(val: number[]) {
  form.category_id = val[0] || null
  form.sub_category_id = val[1] || null
  form.detail_category_id = val[2] || null
}

async function loadTransactions() {
  loading.value = true
  try {
    const params: Record<string, unknown> = { ...filters, page: page.value, page_size: pageSize }
    Object.keys(params).forEach((k) => {
      if (params[k] === '' || params[k] === null || params[k] === undefined) delete params[k]
    })
    const res = await getTransactions(params as any)
    const data = res.data
    transactions.value = data.items || data
    total.value = data.total || (Array.isArray(data) ? data.length : 0)
  } catch { ElMessage.error('加载交易失败') }
  finally { loading.value = false }
}

function openCreate() {
  editingId.value = null
  form.type = 'expense'; form.amountYuan = 0; form.transaction_time = ''
  form.currency = 'CNY'; form.category_id = null; form.sub_category_id = null; form.detail_category_id = null
  form.payment_account_id = null; form.payment_channel_id = null; form.platform_id = null
  form.paid_by = null; form.merchant_name = ''; form.description = ''; form.tag_ids = []
  form.book_id = books.value[0]?.id || 1
  form.originalAmountYuan = 0; form.original_currency = ''; form.exchange_rate = 1
  categoryPath.value = []
  showCreateDialog.value = true
}

function editTxn(row: Transaction) {
  editingId.value = row.id
  form.type = row.type; form.amountYuan = row.amount / 100; form.transaction_time = row.transaction_time
  form.currency = row.currency || 'CNY'
  form.category_id = row.category_id; form.sub_category_id = row.sub_category_id; form.detail_category_id = row.detail_category_id
  form.payment_account_id = row.payment_account_id; form.payment_channel_id = row.payment_channel_id
  form.platform_id = row.platform_id; form.paid_by = row.paid_by
  form.merchant_name = row.merchant_name || ''; form.description = row.description || ''
  form.tag_ids = row.tag_ids || []; form.book_id = row.book_id
  form.originalAmountYuan = (row.original_amount || 0) / 100
  form.original_currency = row.original_currency || ''; form.exchange_rate = row.exchange_rate || 1
  // 构建分类路径
  categoryPath.value = [form.category_id, form.sub_category_id, form.detail_category_id].filter(Boolean) as number[]
  showCreateDialog.value = true
}

async function handleSave() {
  if (!form.amountYuan || !form.transaction_time) { ElMessage.warning('请填写金额和时间'); return }
  saving.value = true
  try {
    const payload: Record<string, unknown> = {
      type: form.type,
      amount: Math.round(form.amountYuan * 100),
      transaction_time: form.transaction_time,
      currency: form.currency,
      book_id: form.book_id,
    }
    if (form.category_id) payload.category_id = form.category_id
    if (form.sub_category_id) payload.sub_category_id = form.sub_category_id
    if (form.detail_category_id) payload.detail_category_id = form.detail_category_id
    if (form.payment_account_id) payload.payment_account_id = form.payment_account_id
    if (form.payment_channel_id) payload.payment_channel_id = form.payment_channel_id
    if (form.platform_id) payload.platform_id = form.platform_id
    if (form.paid_by) payload.paid_by = form.paid_by
    if (form.merchant_name) payload.merchant_name = form.merchant_name
    if (form.description) payload.description = form.description
    if (form.tag_ids.length) payload.tag_ids = form.tag_ids
    if (form.currency !== 'CNY' && form.originalAmountYuan) {
      payload.original_amount = Math.round(form.originalAmountYuan * 100)
      payload.original_currency = form.original_currency || form.currency
      payload.exchange_rate = form.exchange_rate
    }

    if (editingId.value) {
      await updateTransaction(editingId.value, payload as any); ElMessage.success('更新成功')
    } else {
      await createTransaction(payload as any); ElMessage.success('记账成功')
    }
    showCreateDialog.value = false; editingId.value = null; await loadTransactions()
  } catch (err: unknown) {
    ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '保存失败')
  } finally { saving.value = false }
}

async function handleDelete(id: number) {
  try { await deleteTransaction(id); ElMessage.success('已删除'); await loadTransactions() }
  catch { ElMessage.error('删除失败') }
}

onMounted(async () => {
  await Promise.all([
    loadTransactions(),
    getCategories().then((r) => { categoryTree.value = r.data }),
    getCategories().then((r) => {
      // 构建扁平列表用于查找
      const flat: Category[] = []
      function flatten(items: Category[]) {
        for (const item of items) {
          flat.push(item)
          if (item.children) flatten(item.children)
        }
      }
      flatten(r.data)
      categoriesFlat.value = flat
    }),
    getAccounts().then((r) => { accounts.value = r.data }),
    getChannels().then((r) => { channels.value = r.data }),
    getPlatforms().then((r) => { platforms.value = r.data }),
    getTags().then((r) => { tags.value = r.data }),
    getBooks().then((r) => { books.value = r.data }),
  ])
})
</script>

<style scoped>
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}
.page-header h3 { margin: 0; }
.pagination { margin-top: 16px; display: flex; justify-content: flex-end; }
.text-expense { color: #f56c6c; }
.text-income { color: #67c23a; }
</style>
