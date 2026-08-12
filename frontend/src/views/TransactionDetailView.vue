<template>
  <div v-loading="loading">
    <div class="page-header">
      <div class="flex items-center gap-12">
        <el-button @click="router.back()"><el-icon><ArrowLeft /></el-icon> 返回</el-button>
        <h3>交易详情</h3>
      </div>
      <div class="flex items-center gap-8">
        <el-button @click="handleEdit">编辑</el-button>
        <el-popconfirm title="确定删除？" @confirm="handleDelete">
          <template #reference><el-button type="danger">删除</el-button></template>
        </el-popconfirm>
      </div>
    </div>

    <div v-if="txn" class="detail-layout">
      <!-- 金额卡片 -->
      <el-card class="amount-card">
        <div class="text-center">
          <el-tag :type="typeTag[txn.type]" size="large">{{ typeMap[txn.type] }}</el-tag>
          <div class="amount-value" :class="txn.type === 'expense' ? 'text-expense' : txn.type === 'income' ? 'text-income' : 'text-muted'">
            {{ txn.type === 'transfer' ? '' : (txn.type === 'expense' ? '-' : '+') }}{{ formatMoney(txn.amount) }}
          </div>
          <div class="text-muted">{{ txn.merchant_name || txn.description || '无备注' }}</div>
          <div class="text-sm text-muted mt-4">{{ formatTime(txn.transaction_time) }}</div>
        </div>
      </el-card>

      <!-- 基本信息 -->
      <el-card>
        <template #header><span>基本信息</span></template>
        <el-descriptions :column="2" border>
          <el-descriptions-item label="类型">
            <el-tag :type="typeTag[txn.type]" size="small">{{ typeMap[txn.type] }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="金额">
            <span :class="txn.type === 'expense' ? 'text-expense' : 'text-income'">{{ formatMoney(txn.amount) }}</span>
          </el-descriptions-item>
          <el-descriptions-item label="币种">{{ txn.currency }}</el-descriptions-item>
          <el-descriptions-item label="时间">{{ formatTime(txn.transaction_time) }}</el-descriptions-item>
          <el-descriptions-item label="商户">{{ txn.merchant_name || '-' }}</el-descriptions-item>
          <el-descriptions-item label="备注">{{ txn.description || '-' }}</el-descriptions-item>
          <el-descriptions-item label="快速录入">
            <el-tag :type="txn.is_quick_entry ? 'warning' : 'info'" size="small">{{ txn.is_quick_entry ? '是' : '否' }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="完成状态">{{ txn.completion_status }}</el-descriptions-item>
        </el-descriptions>
      </el-card>

      <!-- 账户信息 -->
      <el-card>
        <template #header><span>账户信息</span></template>
        <el-descriptions :column="2" border>
          <el-descriptions-item label="资金来源">
            <span v-if="txn.payment_account_id" class="clickable-cell" @click="router.push(`/accounts`)">{{ getAccountName(txn.payment_account_id) }}</span>
            <span v-else class="text-muted">-</span>
          </el-descriptions-item>
          <el-descriptions-item v-if="txn.type === 'transfer'" label="转入账户">
            <span v-if="txn.source_account_id" class="clickable-cell" @click="router.push(`/accounts`)">{{ getAccountName(txn.source_account_id) }}</span>
            <span v-else class="text-muted">-</span>
          </el-descriptions-item>
          <el-descriptions-item label="支付渠道">
            <span v-if="txn.payment_channel_id">{{ getChannelName(txn.payment_channel_id) }}</span>
            <span v-else class="text-muted">-</span>
          </el-descriptions-item>
          <el-descriptions-item label="购物平台">
            <span v-if="txn.platform_id">{{ getPlatformName(txn.platform_id) }}</span>
            <span v-else class="text-muted">-</span>
          </el-descriptions-item>
          <el-descriptions-item label="账本">{{ getBookName(txn.book_id) }}</el-descriptions-item>
          <el-descriptions-item label="付款人">
            <span v-if="txn.paid_by">{{ getUserName(txn.paid_by) }}</span>
            <span v-else class="text-muted">-</span>
          </el-descriptions-item>
        </el-descriptions>
      </el-card>

      <!-- 分类和标签 -->
      <el-card>
        <template #header><span>分类和标签</span></template>
        <el-descriptions :column="2" border>
          <el-descriptions-item label="分类" :span="2">
            <span v-if="txn.category_id">{{ getCategoryPath(txn.category_id, txn.sub_category_id, txn.detail_category_id) }}</span>
            <span v-else class="text-muted">未分类</span>
          </el-descriptions-item>
          <el-descriptions-item label="标签" :span="2">
            <div v-if="txn.tag_ids && txn.tag_ids.length > 0">
              <el-tag v-for="tagId in txn.tag_ids" :key="tagId" size="small" class="mr-4">{{ getTagName(tagId) }}</el-tag>
            </div>
            <span v-else class="text-muted">无标签</span>
          </el-descriptions-item>
        </el-descriptions>
      </el-card>

      <!-- 外币信息（如有） -->
      <el-card v-if="txn.original_currency && txn.original_currency !== 'CNY'">
        <template #header><span>外币信息</span></template>
        <el-descriptions :column="2" border>
          <el-descriptions-item label="原币金额">{{ formatOriginalAmount(txn.original_amount) }} {{ txn.original_currency }}</el-descriptions-item>
          <el-descriptions-item label="汇率">{{ txn.exchange_rate }}</el-descriptions-item>
        </el-descriptions>
      </el-card>

      <!-- 系统信息 -->
      <el-card>
        <template #header><span>系统信息</span></template>
        <el-descriptions :column="2" border>
          <el-descriptions-item label="交易ID">{{ txn.id }}</el-descriptions-item>
          <el-descriptions-item label="分录ID">{{ txn.entry_id || '-' }}</el-descriptions-item>
          <el-descriptions-item label="版本">v{{ txn.version }}</el-descriptions-item>
          <el-descriptions-item label="记录人">{{ getUserName(txn.recorded_by) }}</el-descriptions-item>
        </el-descriptions>
      </el-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getTransaction, deleteTransaction } from '@/api/transactions'
import { getAccounts } from '@/api/accounts'
import { getChannels, getPlatforms } from '@/api/channels'
import { getBooks } from '@/api/books'
import { getTags } from '@/api/tags'
import { getCategoriesFlat } from '@/api/categories'
import { getMembers } from '@/api/families'
import type { Transaction, PaymentAccount, Channel, Platform, AccountBook, Tag, Category } from '@/types'
import type { FamilyMember } from '@/api/families'

const route = useRoute()
const router = useRouter()

const loading = ref(false)
const txn = ref<Transaction | null>(null)
const accounts = ref<PaymentAccount[]>([])
const channels = ref<Channel[]>([])
const platforms = ref<Platform[]>([])
const books = ref<AccountBook[]>([])
const tags = ref<Tag[]>([])
const categories = ref<Category[]>([])
const members = ref<FamilyMember[]>([])

const typeMap: Record<string, string> = { expense: '支出', income: '收入', transfer: '资金转移' }
const typeTag: Record<string, string> = { expense: 'danger', income: 'success', transfer: 'info' }

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }
function formatOriginalAmount(val: number | null) { return val ? `${(val / 100).toFixed(2)}` : '-' }
function formatTime(t: string) { return new Date(t).toLocaleString('zh-CN') }

function getAccountName(id: number) { return accounts.value.find((a) => a.id === id)?.name || `账户${id}` }
function getChannelName(id: number) { return channels.value.find((c) => c.id === id)?.name || `渠道${id}` }
function getPlatformName(id: number) { return platforms.value.find((p) => p.id === id)?.name || `平台${id}` }
function getBookName(id: number) { return books.value.find((b) => b.id === id)?.name || `账本${id}` }
function getTagName(id: number) { return tags.value.find((t) => t.id === id)?.name || `标签${id}` }
function getUserName(id: number) { return members.value.find((m) => m.id === id)?.nickname || `用户${id}` }

function getCategoryPath(catId: number | null, subId: number | null, detailId: number | null) {
  const parts = []
  if (catId) parts.push(categories.value.find((c) => c.id === catId)?.name || `分类${catId}`)
  if (subId) parts.push(categories.value.find((c) => c.id === subId)?.name || `分类${subId}`)
  if (detailId) parts.push(categories.value.find((c) => c.id === detailId)?.name || `分类${detailId}`)
  return parts.join(' > ')
}

function handleEdit() {
  router.push({ path: '/transactions', query: { edit: txn.value?.id } })
}

async function handleDelete() {
  if (!txn.value) return
  try {
    await deleteTransaction(txn.value.id)
    ElMessage.success('已删除')
    router.push('/transactions')
  } catch { ElMessage.error('删除失败') }
}

onMounted(async () => {
  loading.value = true
  const txnId = Number(route.params.id)
  try {
    const [txnRes, ...rest] = await Promise.all([
      getTransaction(txnId),
      getAccounts().then((r) => { accounts.value = r.data }),
      getChannels().then((r) => { channels.value = r.data }),
      getPlatforms().then((r) => { platforms.value = r.data }),
      getBooks().then((r) => { books.value = r.data }),
      getTags().then((r) => { tags.value = r.data }),
      getCategoriesFlat().then((r) => { categories.value = r.data }),
      getMembers().then((r) => { members.value = r.data }).catch(() => {}),
    ])
    txn.value = txnRes.data
  } catch { ElMessage.error('加载失败') }
  finally { loading.value = false }
})
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
.detail-layout { display: flex; flex-direction: column; gap: 16px; max-width: 800px; }
.amount-card :deep(.el-card__body) { padding: 24px; }
.amount-value { font-size: 32px; font-weight: 700; margin: 12px 0 8px; }
.clickable-cell { cursor: pointer; color: var(--color-primary); }
.clickable-cell:hover { text-decoration: underline; }
</style>
