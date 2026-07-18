<template>
  <div>
    <div class="page-header">
      <h3>报销管理</h3>
      <div>
        <el-select v-model="filterStatus" clearable placeholder="状态" style="width: 120px; margin-right: 8px;" @change="load">
          <el-option label="草稿" value="draft" /><el-option label="待审批" value="submitted" />
          <el-option label="已审批" value="approved" /><el-option label="已到账" value="received" />
        </el-select>
        <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon> 新建</el-button>
      </div>
    </div>
    <el-card>
      <el-table :data="items" stripe v-loading="loading">
        <el-table-column prop="title" label="标题" />
        <el-table-column prop="status" label="状态" width="90">
          <template #default="{ row }">
            <el-tag :type="statusType[row.status]" size="small">{{ statusMap[row.status] }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="金额" align="right"><template #default="{ row }">{{ formatMoney(row.total_amount) }}</template></el-table-column>
        <el-table-column label="明细" width="70"><template #default="{ row }">{{ row.items?.length || 0 }}项</template></el-table-column>
        <el-table-column label="操作" width="240">
          <template #default="{ row }">
            <el-button v-if="row.status === 'draft'" link type="success" size="small" @click="handleSubmit(row.id)">提交</el-button>
            <el-button v-if="row.status === 'submitted'" link type="primary" size="small" @click="handleApprove(row.id)">审批</el-button>
            <el-button v-if="row.status === 'approved'" link type="warning" size="small" @click="openReceive(row.id)">到账</el-button>
            <el-button link type="primary" size="small" @click="viewDetail(row)">查看</el-button>
            <el-popconfirm v-if="row.status === 'draft'" title="确定删除？" @confirm="handleDelete(row.id)">
              <template #reference><el-button link type="danger" size="small">删除</el-button></template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 新建报销对话框 -->
    <el-dialog v-model="showDialog" title="新建报销" width="700px" destroy-on-close>
      <el-form :model="form" label-width="80px">
        <el-form-item label="标题"><el-input v-model="form.title" /></el-form-item>
        <el-form-item label="备注"><el-input v-model="form.description" /></el-form-item>
        <el-divider>选择要报销的交易</el-divider>
        <div style="margin-bottom: 12px;">
          <el-input v-model="searchKeyword" placeholder="搜索交易备注/商户" clearable style="width: 200px; margin-right: 8px;" />
          <el-button @click="searchTransactions">搜索</el-button>
        </div>
        <el-table :data="availableTxns" stripe size="small" max-height="250" @selection-change="onTxnSelect" style="margin-bottom: 16px;">
          <el-table-column type="selection" width="50" />
          <el-table-column prop="transaction_time" label="时间" width="160">
            <template #default="{ row }">{{ formatTime(row.transaction_time) }}</template>
          </el-table-column>
          <el-table-column prop="merchant_name" label="商户" />
          <el-table-column prop="description" label="备注" />
          <el-table-column label="金额" align="right" width="100">
            <template #default="{ row }">{{ formatMoney(row.amount) }}</template>
          </el-table-column>
        </el-table>

        <el-divider>已选交易</el-divider>
        <div v-if="form.items.length === 0" style="color: #909399; padding: 20px; text-align: center;">
          请从上方表格中选择要报销的交易
        </div>
        <div v-for="(item, i) in form.items" :key="i" style="display: flex; gap: 8px; margin-bottom: 8px; align-items: center;">
          <span style="flex: 1;">{{ item.description }}</span>
          <span style="width: 100px; text-align: right;">{{ formatMoney(item.amount) }}</span>
          <el-button type="danger" :icon="Delete" circle size="small" @click="removeItem(i)" />
        </div>
        <div v-if="form.items.length > 0" style="text-align: right; font-weight: bold; margin-top: 8px;">
          合计: {{ formatMoney(totalAmount) }}
        </div>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleCreate">保存</el-button>
      </template>
    </el-dialog>

    <!-- 详情对话框 -->
    <el-dialog v-model="showDetail" title="报销详情" width="600px">
      <el-descriptions :column="2" border v-if="detailItem">
        <el-descriptions-item label="标题">{{ detailItem.title }}</el-descriptions-item>
        <el-descriptions-item label="状态">{{ statusMap[detailItem.status] }}</el-descriptions-item>
        <el-descriptions-item label="总额">{{ formatMoney(detailItem.total_amount) }}</el-descriptions-item>
        <el-descriptions-item label="备注">{{ detailItem.description }}</el-descriptions-item>
      </el-descriptions>
      <el-table :data="detailItem?.items || []" style="margin-top: 12px;" stripe>
        <el-table-column prop="transaction_id" label="交易ID" width="80" />
        <el-table-column prop="description" label="描述" />
        <el-table-column label="金额" align="right"><template #default="{ row }">{{ formatMoney(row.amount) }}</template></el-table-column>
      </el-table>
    </el-dialog>

    <!-- 到账对话框 -->
    <el-dialog v-model="showReceive" title="确认到账" width="360px">
      <el-form label-width="80px">
        <el-form-item label="到账金额(分)"><el-input-number v-model="receiveAmount" :min="1" style="width: 100%;" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showReceive = false">取消</el-button>
        <el-button type="primary" @click="handleReceive">确认</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { Plus, Delete } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getReimbursements, createReimbursement, submitReimbursement, approveReimbursement, receiveReimbursement, deleteReimbursement } from '@/api/reimbursements'
import { getTransactions } from '@/api/transactions'
import type { Reimbursement, Transaction } from '@/types'

const loading = ref(false)
const saving = ref(false)
const items = ref<Reimbursement[]>([])
const availableTxns = ref<Transaction[]>([])
const filterStatus = ref('')
const showDialog = ref(false)
const showDetail = ref(false)
const showReceive = ref(false)
const detailItem = ref<Reimbursement | null>(null)
const receiveId = ref(0)
const receiveAmount = ref(0)
const searchKeyword = ref('')

const statusMap: Record<string, string> = { draft: '草稿', submitted: '待审批', approved: '已审批', received: '已到账' }
const statusType: Record<string, string> = { draft: 'info', submitted: 'warning', approved: 'success', received: '' }

const form = reactive({
  title: '', description: '',
  items: [] as { transaction_id: number; amount: number; description: string }[],
})

const totalAmount = computed(() => form.items.reduce((sum, item) => sum + item.amount, 0))

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }
function formatTime(t: string) { return t ? new Date(t).toLocaleString('zh-CN') : '' }

async function load() {
  loading.value = true
  try { items.value = (await getReimbursements({ status: filterStatus.value || undefined })).data }
  finally { loading.value = false }
}

async function searchTransactions() {
  try {
    const params: Record<string, unknown> = { page_size: 50 }
    if (searchKeyword.value) params.keyword = searchKeyword.value
    const res = await getTransactions(params as any)
    availableTxns.value = res.data.items || res.data
  } catch { ElMessage.error('搜索失败') }
}

function openCreate() {
  form.title = ''
  form.description = ''
  form.items = []
  searchKeyword.value = ''
  availableTxns.value = []
  showDialog.value = true
}

function onTxnSelect(selection: Transaction[]) {
  form.items = selection.map((txn) => ({
    transaction_id: txn.id,
    amount: txn.amount,
    description: txn.description || txn.merchant_name || `交易${txn.id}`,
  }))
}

function removeItem(index: number) {
  form.items.splice(index, 1)
}

async function handleCreate() {
  if (!form.title) { ElMessage.warning('请填写标题'); return }
  if (form.items.length === 0) { ElMessage.warning('请至少选择一笔交易'); return }
  saving.value = true
  try {
    await createReimbursement({
      title: form.title,
      total_amount: totalAmount.value,
      description: form.description || undefined,
      items: form.items,
    })
    ElMessage.success('创建成功')
    showDialog.value = false
    await load()
  } catch (err: unknown) {
    ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '创建失败')
  } finally { saving.value = false }
}

async function handleSubmit(id: number) {
  try { await submitReimbursement(id); ElMessage.success('已提交'); await load() } catch { ElMessage.error('提交失败') }
}

async function handleApprove(id: number) {
  try { await approveReimbursement(id); ElMessage.success('已审批'); await load() } catch { ElMessage.error('审批失败') }
}

function openReceive(id: number) { receiveId.value = id; receiveAmount.value = 0; showReceive.value = true }

async function handleReceive() {
  if (!receiveAmount.value) { ElMessage.warning('请填写金额'); return }
  try { await receiveReimbursement(receiveId.value, { received_amount: receiveAmount.value }); ElMessage.success('已到账'); showReceive.value = false; await load() }
  catch { ElMessage.error('操作失败') }
}

function viewDetail(row: Reimbursement) { detailItem.value = row; showDetail.value = true }

async function handleDelete(id: number) {
  try { await deleteReimbursement(id); ElMessage.success('已删除'); await load() } catch { ElMessage.error('删除失败') }
}

onMounted(load)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
