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
          <el-select v-model="filters.book_id" clearable placeholder="全部" class="w-120" @change="loadTransactions">
            <el-option v-for="b in books" :key="b.id" :label="b.name" :value="b.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="类型">
          <el-select v-model="filters.type" clearable placeholder="全部" class="w-100">
            <el-option label="支出" value="expense" />
            <el-option label="收入" value="income" />
            <el-option label="资金转移" value="transfer" />
          </el-select>
        </el-form-item>
        <el-form-item label="日期">
          <el-date-picker v-model="dateRange" type="daterange" start-placeholder="开始" end-placeholder="结束"
            value-format="YYYY-MM-DD" @change="onDateChange" class="w-260" />
        </el-form-item>
        <el-form-item label="账户">
          <el-select v-model="filters.payment_account_id" clearable placeholder="全部" class="w-120">
            <el-option v-for="a in accounts" :key="a.id" :label="a.name" :value="a.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="渠道">
          <el-select v-model="filters.payment_channel_id" clearable placeholder="全部" class="w-100">
            <el-option v-for="c in channels" :key="c.id" :label="c.name" :value="c.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="平台">
          <el-select v-model="filters.platform_id" clearable placeholder="全部" class="w-100">
            <el-option v-for="p in platforms" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="币种">
          <el-select v-model="filters.currency" clearable placeholder="全部" class="w-80">
            <el-option label="CNY" value="CNY" /><el-option label="USD" value="USD" />
            <el-option label="EUR" value="EUR" /><el-option label="JPY" value="JPY" />
            <el-option label="HKD" value="HKD" />
          </el-select>
        </el-form-item>
        <el-form-item label="关键词">
          <el-input v-model="filters.keyword" placeholder="搜索备注/商户" clearable class="w-140" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="loadTransactions">查询</el-button>
          <el-button @click="clearFilters">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card class="mt-16">
      <!-- 活跃筛选条件标签 -->
      <div v-if="hasActiveFilters" class="flex items-center gap-8 mb-12 flex-wrap">
        <span class="text-sm text-muted">筛选中：</span>
        <el-tag v-if="filters.book_id" closable @close="filters.book_id = null; loadTransactions()" size="small">
          账本: {{ getBookName(filters.book_id) }}
        </el-tag>
        <el-tag v-if="filters.type" closable @close="filters.type = ''; loadTransactions()" size="small">
          类型: {{ typeMap[filters.type] }}
        </el-tag>
        <el-tag v-if="filters.payment_account_id" closable @close="filters.payment_account_id = null; loadTransactions()" size="small">
          账户: {{ getAccountName(filters.payment_account_id) }}
        </el-tag>
        <el-tag v-if="filters.payment_channel_id" closable @close="filters.payment_channel_id = null; loadTransactions()" size="small">
          渠道: {{ getChannelName(filters.payment_channel_id) }}
        </el-tag>
        <el-tag v-if="filters.platform_id" closable @close="filters.platform_id = null; loadTransactions()" size="small">
          平台: {{ getPlatformName(filters.platform_id) }}
        </el-tag>
        <el-tag v-if="filters.category_id" closable @close="filters.category_id = null; loadTransactions()" size="small">
          分类: {{ getCategoryName(filters.category_id) }}
        </el-tag>
        <el-tag v-if="filters.merchant_name" closable @close="filters.merchant_name = ''; loadTransactions()" size="small">
          商户: {{ filters.merchant_name }}
        </el-tag>
        <el-tag v-if="filters.currency" closable @close="filters.currency = ''; loadTransactions()" size="small">
          币种: {{ filters.currency }}
        </el-tag>
        <el-tag v-if="filters.keyword" closable @close="filters.keyword = ''; loadTransactions()" size="small">
          关键词: {{ filters.keyword }}
        </el-tag>
        <el-button link type="primary" size="small" @click="clearFilters">清除全部</el-button>
      </div>

      <!-- 批量操作栏 -->
      <div v-if="selectedIds.length > 0" class="flex items-center gap-12 mb-12" style="padding: 8px 12px; background: var(--color-bg-selected); border-radius: var(--border-radius);">
        <span class="text-sm text-regular">已选 {{ selectedIds.length }} 条</span>
        <el-button size="small" type="danger" @click="handleBatchDelete">批量删除</el-button>
        <el-button size="small" @click="selectedIds = []">取消选择</el-button>
      </div>

      <el-table :data="transactions" stripe v-loading="loading" class="w-full" border
        :max-height="tableMaxHeight" @selection-change="handleSelectionChange" @header-dragend="onColumnResize">
        <el-table-column type="selection" width="45" fixed />
        <el-table-column prop="transaction_time" label="时间" :width="colWidth('time', 160)" fixed resizable>
          <template #default="{ row }">{{ formatTime(row.transaction_time) }}</template>
        </el-table-column>
        <el-table-column label="账本" :width="colWidth('book', 80)" resizable>
          <template #default="{ row }">
            <span v-if="row.book_id" class="clickable-cell" @click="quickFilter('book_id', row.book_id)">{{ getBookName(row.book_id) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="type" label="类型" :width="colWidth('type', 120)" resizable>
          <template #default="{ row }">
            <el-tag :type="typeTag[row.type]" size="small" class="clickable-cell" @click="quickFilter('type', row.type)">{{ typeMap[row.type] }}</el-tag>
            <el-tag v-if="row.is_quick_entry" size="small" type="warning" class="ml-4">快速</el-tag>
            <span v-if="row.type === 'transfer' && row.payment_account_id" class="text-sm text-muted ml-4">
              → {{ getAccountName(row.payment_account_id) }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="分类" :width="colWidth('category', 120)" resizable>
          <template #default="{ row }">
            <span v-if="row.category_id" class="clickable-cell" @click="quickFilter('category_id', row.category_id)">{{ getCategoryPath(row.category_id, row.sub_category_id) }}</span>
            <span v-else class="text-placeholder">未分类</span>
          </template>
        </el-table-column>
        <el-table-column prop="merchant_name" label="商户" :width="colWidth('merchant', 120)" show-overflow-tooltip resizable>
          <template #default="{ row }">
            <span v-if="row.merchant_name" class="clickable-cell" @click="quickFilter('merchant_name', row.merchant_name)">{{ row.merchant_name }}</span>
            <span v-else class="text-placeholder">-</span>
          </template>
        </el-table-column>
        <el-table-column label="资金来源" :width="colWidth('account', 120)" resizable>
          <template #default="{ row }">
            <template v-if="row.type === 'transfer'">
              <span class="text-muted">{{ getAccountName(row.source_account_id) || '未知' }}</span>
              <span style="margin: 0 4px;">→</span>
              <span>{{ getAccountName(row.payment_account_id) || '未知' }}</span>
            </template>
            <template v-else>
              <span v-if="row.payment_account_id" class="clickable-cell" @click="quickFilter('payment_account_id', row.payment_account_id)">{{ getAccountName(row.payment_account_id) }}</span>
              <span v-else class="text-placeholder">-</span>
            </template>
          </template>
        </el-table-column>
        <el-table-column label="支付渠道" :width="colWidth('channel', 90)" resizable>
          <template #default="{ row }">
            <span v-if="row.payment_channel_id" class="clickable-cell" @click="quickFilter('payment_channel_id', row.payment_channel_id)">{{ getChannelName(row.payment_channel_id) }}</span>
            <span v-else class="text-placeholder">-</span>
          </template>
        </el-table-column>
        <el-table-column label="平台" :width="colWidth('platform', 80)" resizable>
          <template #default="{ row }">
            <span v-if="row.platform_id" class="clickable-cell" @click="quickFilter('platform_id', row.platform_id)">{{ getPlatformName(row.platform_id) }}</span>
            <span v-else class="text-placeholder">-</span>
          </template>
        </el-table-column>
        <el-table-column label="币种" :width="colWidth('currency', 60)" resizable>
          <template #default="{ row }">
            <span class="clickable-cell" @click="quickFilter('currency', row.currency || 'CNY')">{{ row.currency || 'CNY' }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="description" label="备注" :min-width="120" show-overflow-tooltip resizable />
        <el-table-column label="标签" :width="colWidth('tags', 120)" resizable>
          <template #default="{ row }">
            <el-tag v-for="tagId in (row.tag_ids || [])" :key="tagId" size="small" class="mr-4">
              {{ getTagName(tagId) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="amount" label="金额" align="right" :width="colWidth('amount', 110)" fixed="right" resizable>
          <template #default="{ row }">
            <span v-if="row.type === 'transfer'" class="text-muted">
              {{ formatMoney(row.amount) }}
            </span>
            <span v-else :class="row.type === 'expense' ? 'text-expense' : 'text-income'">
              {{ row.type === 'expense' ? '-' : '+' }}{{ formatMoney(row.amount) }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="操作" :width="colWidth('actions', 120)" fixed="right" resizable>
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
          v-model:page-size="pageSize"
          :page-sizes="[20, 50, 100, 200]"
          :total="total"
          layout="sizes, prev, pager, next, total"
          @current-change="loadTransactions"
          @size-change="onPageSizeChange"
        />
      </div>
    </el-card>

    <!-- 新建/编辑对话框 -->
    <el-dialog v-model="showCreateDialog" :title="editingId ? '编辑交易' : '记一笔'" width="650px">
      <el-form :model="form" label-width="80px">
        <el-row :gutter="16">
          <el-col :span="8">
            <el-form-item label="类型">
              <el-radio-group v-model="form.type">
                <el-radio-button value="expense">支出</el-radio-button>
                <el-radio-button value="income">收入</el-radio-button>
                <el-radio-button value="transfer">资金转移</el-radio-button>
              </el-radio-group>
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="账本">
              <el-select v-model="form.book_id" class="w-full">
                <el-option v-for="b in books" :key="b.id" :label="b.name" :value="b.id" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="币种">
              <el-select v-model="form.currency" class="w-full">
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
              <el-input-number v-model="form.amountYuan" :min="0.01" :precision="2" class="w-full" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="时间">
              <el-date-picker v-model="form.transaction_time" type="datetime" value-format="YYYY-MM-DDTHH:mm:ss"
                class="w-full" />
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
            class="w-full"
            @change="onCategoryChange"
          />
        </el-form-item>

        <el-row :gutter="16">
          <el-col :span="12">
            <el-form-item :label="form.type === 'transfer' ? '转出账户' : '资金来源'">
              <el-select v-model="form.payment_account_id" clearable filterable placeholder="选择账户" class="w-full">
                <el-option v-for="a in accounts" :key="a.id" :label="a.name" :value="a.id" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item v-if="form.type === 'transfer'" label="转入账户">
              <el-select v-model="form.destination_account_id" clearable filterable placeholder="选择目标账户" class="w-full">
                <el-option v-for="a in accounts" :key="a.id" :label="a.name" :value="a.id" />
              </el-select>
            </el-form-item>
            <el-form-item v-else label="支付渠道">
              <el-select v-model="form.payment_channel_id" clearable filterable placeholder="选择渠道" class="w-full">
                <el-option v-for="c in channels" :key="c.id" :label="c.name" :value="c.id" />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>

        <el-row :gutter="16">
          <el-col :span="12">
            <el-form-item label="交易平台">
              <el-select v-model="form.platform_id" clearable filterable placeholder="选择平台" class="w-full">
                <el-option v-for="p in platforms" :key="p.id" :label="p.name" :value="p.id" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="付款人">
              <el-select v-model="form.paid_by" clearable filterable placeholder="选择付款人" class="w-full">
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
          <el-select v-model="form.tag_ids" multiple clearable placeholder="选择标签" class="w-full">
            <el-option v-for="t in tags" :key="t.id" :label="t.name" :value="t.id" />
          </el-select>
        </el-form-item>

        <!-- 外币信息（仅非CNY时显示） -->
        <template v-if="form.currency !== 'CNY'">
          <el-divider>外币信息</el-divider>
          <el-row :gutter="16">
            <el-col :span="8">
              <el-form-item label="原币金额">
                <el-input-number v-model="form.originalAmountYuan" :min="0.01" :precision="2" class="w-full" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="原币种">
                <el-input v-model="form.original_currency" disabled />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="汇率">
                <el-input-number v-model="form.exchange_rate" :min="0.000001" :precision="6" class="w-full" />
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
import { ref, reactive, onMounted, nextTick, computed } from 'vue'
import { Plus } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getTransactions, createTransaction, updateTransaction, deleteTransaction } from '@/api/transactions'
import { getCategories } from '@/api/categories'
import { getAccounts } from '@/api/accounts'
import { getChannels, getPlatforms } from '@/api/channels'
import { getTags } from '@/api/tags'
import { getBooks } from '@/api/books'
import { getMembers } from '@/api/families'
import type { Transaction, Category, PaymentAccount, Tag, Channel, Platform, AccountBook } from '@/types'

interface FamilyMember { id: number; nickname: string }

const loading = ref(false)
const saving = ref(false)
const transactions = ref<Transaction[]>([])
const selectedIds = ref<number[]>([])
const categoryTree = ref<Category[]>([])
const categoriesFlat = ref<Category[]>([])
const accounts = ref<PaymentAccount[]>([])
const channels = ref<Channel[]>([])
const platforms = ref<Platform[]>([])
const tags = ref<Tag[]>([])
const books = ref<AccountBook[]>([])
const familyMembers = ref<FamilyMember[]>([])
const page = ref(1)
const pageSize = ref(20)
const total = ref(0)
const dateRange = ref<[string, string] | null>(null)
const showCreateDialog = ref(false)
const editingId = ref<number | null>(null)
const categoryPath = ref<number[]>([])

const typeMap: Record<string, string> = { expense: '支出', income: '收入', transfer: '资金转移' }
const typeTag: Record<string, string> = { expense: 'danger', income: 'success', transfer: 'info' }

// 表格最大高度（视口高度减去筛选栏等区域），实现固定表头
const tableMaxHeight = computed(() => {
  return window.innerHeight - 320
})

// 列宽持久化
const COL_WIDTHS_KEY = 'txn_col_widths'
const savedColWidths = ref<Record<string, number>>({})

function loadColWidths() {
  try {
    const saved = localStorage.getItem(COL_WIDTHS_KEY)
    if (saved) savedColWidths.value = JSON.parse(saved)
  } catch { /* ignore */ }
}

function saveColWidths() {
  localStorage.setItem(COL_WIDTHS_KEY, JSON.stringify(savedColWidths.value))
}

function colWidth(name: string, defaultWidth: number): number {
  return savedColWidths.value[name] || defaultWidth
}

function onColumnResize(newWidth: number, _: unknown, column: { property?: string; label?: string }) {
  // 通过 property 或 label 匹配列名
  const labelMap: Record<string, string> = {
    '时间': 'time', '账本': 'book', '类型': 'type', '分类': 'category',
    '商户': 'merchant', '资金来源': 'account', '支付渠道': 'channel',
    '平台': 'platform', '币种': 'currency', '备注': 'desc', '标签': 'tags',
    '金额': 'amount', '操作': 'actions',
  }
  const name = labelMap[column.label || ''] || column.property || ''
  if (name) {
    savedColWidths.value[name] = newWidth
    saveColWidths()
  }
}

const filters = reactive({
  book_id: null as number | null,
  type: '', keyword: '', start_date: '', end_date: '',
  payment_account_id: null as number | null,
  payment_channel_id: null as number | null,
  platform_id: null as number | null,
  category_id: null as number | null,
  merchant_name: '',
  currency: '',
})

// 是否有活跃的筛选条件
const hasActiveFilters = computed(() => {
  return !!(filters.book_id || filters.type || filters.payment_account_id ||
    filters.payment_channel_id || filters.platform_id || filters.category_id ||
    filters.merchant_name || filters.currency || filters.keyword || dateRange.value)
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
  destination_account_id: null as number | null,
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

// 快捷筛选：点击表格中的账户、渠道、平台等字段直接筛选
function quickFilter(field: string, value: string | number) {
  (filters as Record<string, unknown>)[field] = value
  page.value = 1
  loadTransactions()
}

// 重置所有筛选条件
function clearFilters() {
  filters.book_id = null; filters.type = ''; filters.keyword = ''
  filters.start_date = ''; filters.end_date = ''
  filters.payment_account_id = null; filters.payment_channel_id = null
  filters.platform_id = null; filters.category_id = null
  filters.merchant_name = ''; filters.currency = ''
  dateRange.value = null
  page.value = 1
  loadTransactions()
}

async function loadTransactions() {
  loading.value = true
  try {
    const params: Record<string, unknown> = { ...filters, page: page.value, page_size: pageSize.value }
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

function onPageSizeChange() {
  page.value = 1
  loadTransactions()
}

function openCreate() {
  editingId.value = null
  form.type = 'expense'; form.amountYuan = 0; form.transaction_time = ''
  form.currency = 'CNY'
  form.category_id = null; form.sub_category_id = null; form.detail_category_id = null
  form.payment_account_id = null; form.destination_account_id = null
  form.payment_channel_id = null; form.platform_id = null
  form.paid_by = null; form.merchant_name = ''; form.description = ''; form.tag_ids = []
  const defaultBook = books.value.find((b) => b.is_default) || books.value[0]
  form.book_id = defaultBook?.id || 0
  form.originalAmountYuan = 0; form.original_currency = ''; form.exchange_rate = 1
  categoryPath.value = []
  showCreateDialog.value = true
}

function editTxn(row: Transaction) {
  editingId.value = row.id
  form.type = row.type; form.amountYuan = row.amount / 100; form.transaction_time = row.transaction_time
  form.currency = row.currency || 'CNY'
  form.category_id = row.category_id; form.sub_category_id = row.sub_category_id; form.detail_category_id = row.detail_category_id
  form.payment_account_id = row.type === 'transfer' ? row.source_account_id : row.payment_account_id
  form.destination_account_id = row.type === 'transfer' ? row.payment_account_id : null
  form.payment_channel_id = row.payment_channel_id
  form.platform_id = row.platform_id; form.paid_by = row.paid_by
  form.merchant_name = row.merchant_name || ''; form.description = row.description || ''
  form.tag_ids = row.tag_ids || []; form.book_id = row.book_id
  form.originalAmountYuan = (row.original_amount || 0) / 100
  form.original_currency = row.original_currency || ''; form.exchange_rate = row.exchange_rate || 1
  // 设置分类路径
  categoryPath.value = [form.category_id, form.sub_category_id, form.detail_category_id].filter(Boolean) as number[]
  showCreateDialog.value = true
}

async function handleSave() {
  if (!form.amountYuan || !form.transaction_time) { ElMessage.warning('请填写金额和时间'); return }
  if (form.type === 'transfer' && !form.destination_account_id) { ElMessage.warning('请选择转入账户'); return }
  saving.value = true
  try {
    const payload: Record<string, unknown> = {
      type: form.type,
      amount: Math.round(form.amountYuan * 100),
      transaction_time: form.transaction_time,
      currency: form.currency,
      book_id: form.book_id,
    }
    if (form.type === 'transfer') {
      payload.payment_account_id = form.payment_account_id
      payload.destination_account_id = form.destination_account_id
    } else {
      if (form.payment_account_id) payload.payment_account_id = form.payment_account_id
      if (form.payment_channel_id) payload.payment_channel_id = form.payment_channel_id
      if (form.platform_id) payload.platform_id = form.platform_id
    }
    if (form.category_id) payload.category_id = form.category_id
    if (form.sub_category_id) payload.sub_category_id = form.sub_category_id
    if (form.detail_category_id) payload.detail_category_id = form.detail_category_id
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

function handleSelectionChange(rows: Transaction[]) {
  selectedIds.value = rows.map((r) => r.id)
}

async function handleBatchDelete() {
  if (selectedIds.value.length === 0) return
  try {
    await ElMessageBox.confirm(`确定删除选中的 ${selectedIds.value.length} 条记录？`, '批量删除', { type: 'warning' })
    let success = 0
    for (const id of selectedIds.value) {
      try { await deleteTransaction(id); success++ } catch { /* skip */ }
    }
    ElMessage.success(`成功删除 ${success} 条`)
    selectedIds.value = []
    await loadTransactions()
  } catch { /* cancelled */ }
}

onMounted(async () => {
  loadColWidths()
  await Promise.all([
    loadTransactions(),
    getCategories().then((r) => {
      categoryTree.value = r.data
      const flat: Category[] = []
      function flatten(items: Category[]) { for (const item of items) { flat.push(item); if (item.children) flatten(item.children) } }
      flatten(r.data)
      categoriesFlat.value = flat
    }),
    getAccounts().then((r) => { accounts.value = r.data }),
    getChannels().then((r) => { channels.value = r.data }),
    getPlatforms().then((r) => { platforms.value = r.data }),
    getTags().then((r) => { tags.value = r.data }),
    getBooks().then((r) => { books.value = r.data }),
    getMembers().then((r) => { familyMembers.value = r.data }).catch(() => {}),
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
.text-expense { color: var(--color-expense); }
.text-income { color: var(--color-income); }
.clickable-cell {
  cursor: pointer;
  transition: opacity 0.2s;
}
.clickable-cell:hover {
  opacity: 0.7;
  text-decoration: underline;
}
/* 保留列宽拖拽功能，但隐藏行边框 */
.el-table--border :deep(th.el-table__cell) {
  border-right: 1px solid var(--color-border-light);
}
.el-table--border :deep(td.el-table__cell) {
  border-right: none;
}
.el-table :deep(td.el-table__cell),
.el-table :deep(th.el-table__cell.is-leaf) {
  border-bottom: none;
}
</style>
