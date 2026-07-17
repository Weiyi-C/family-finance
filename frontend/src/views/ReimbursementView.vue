<template>
  <div>
    <div class="page-header">
      <h3>报销管理</h3>
      <div>
        <el-select v-model="filterStatus" clearable placeholder="状态" style="width: 120px; margin-right: 8px;" @change="load">
          <el-option label="草稿" value="draft" /><el-option label="待审批" value="submitted" />
          <el-option label="已审批" value="approved" /><el-option label="已到账" value="received" />
        </el-select>
        <el-button type="primary" @click="showDialog = true"><el-icon><Plus /></el-icon> 新建</el-button>
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

    <el-dialog v-model="showDialog" title="新建报销" width="560px" destroy-on-close>
      <el-form :model="form" label-width="80px">
        <el-form-item label="标题"><el-input v-model="form.title" /></el-form-item>
        <el-form-item label="总额(分)"><el-input-number v-model="form.total_amount" :min="1" style="width: 100%;" /></el-form-item>
        <el-form-item label="备注"><el-input v-model="form.description" /></el-form-item>
        <el-divider>明细项</el-divider>
        <div v-for="(item, i) in form.items" :key="i" style="display: flex; gap: 8px; margin-bottom: 8px;">
          <el-input-number v-model="item.transaction_id" :min="1" placeholder="交易ID" style="flex: 1;" />
          <el-input-number v-model="item.amount" :min="1" placeholder="金额" style="flex: 1;" />
          <el-input v-model="item.description" placeholder="描述" style="flex: 2;" />
          <el-button type="danger" :icon="Delete" circle size="small" @click="form.items.splice(i, 1)" />
        </div>
        <el-button @click="form.items.push({ transaction_id: 0, amount: 0, description: '' })">添加明细</el-button>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleCreate">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="showDetail" title="报销详情" width="500px">
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
import { ref, reactive, onMounted } from 'vue'
import { Plus, Delete } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getReimbursements, createReimbursement, submitReimbursement, approveReimbursement, receiveReimbursement, deleteReimbursement } from '@/api/reimbursements'
import type { Reimbursement } from '@/types'

const loading = ref(false)
const saving = ref(false)
const items = ref<Reimbursement[]>([])
const filterStatus = ref('')
const showDialog = ref(false)
const showDetail = ref(false)
const showReceive = ref(false)
const detailItem = ref<Reimbursement | null>(null)
const receiveId = ref(0)
const receiveAmount = ref(0)

const statusMap: Record<string, string> = { draft: '草稿', submitted: '待审批', approved: '已审批', received: '已到账' }
const statusType: Record<string, string> = { draft: 'info', submitted: 'warning', approved: 'success', received: '' }

const form = reactive({
  title: '', total_amount: 0, description: '',
  items: [{ transaction_id: 0, amount: 0, description: '' }] as { transaction_id: number; amount: number; description: string }[],
})

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

async function load() {
  loading.value = true
  try { items.value = (await getReimbursements({ status: filterStatus.value || undefined })).data }
  finally { loading.value = false }
}

async function handleCreate() {
  if (!form.title || !form.total_amount) { ElMessage.warning('请填写标题和总额'); return }
  saving.value = true
  try {
    await createReimbursement({
      title: form.title, total_amount: form.total_amount, description: form.description || undefined,
      items: form.items.filter((i) => i.transaction_id && i.amount).map((i) => ({ transaction_id: i.transaction_id, amount: i.amount, description: i.description || undefined })),
    })
    ElMessage.success('创建成功'); showDialog.value = false; await load()
  } catch (err: unknown) { ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '创建失败') }
  finally { saving.value = false }
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
