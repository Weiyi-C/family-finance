<template>
  <div>
    <div class="page-header">
      <h3>周期性交易</h3>
      <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon> 新建</el-button>
    </div>
    <el-card>
      <el-table :data="items" stripe v-loading="loading">
        <el-table-column prop="type" label="类型" width="70">
          <template #default="{ row }">
            <el-tag :type="row.type === 'expense' ? 'danger' : 'success'" size="small">{{ row.type === 'expense' ? '支出' : '收入' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="金额" align="right"><template #default="{ row }">{{ formatMoney(row.amount) }}</template></el-table-column>
        <el-table-column prop="frequency" label="频率" width="80" />
        <el-table-column prop="merchant_name" label="商户" />
        <el-table-column prop="description" label="备注" />
        <el-table-column prop="next_generate" label="下次生成" width="110" />
        <el-table-column prop="is_active" label="状态" width="70">
          <template #default="{ row }"><el-tag :type="row.is_active ? 'success' : 'info'" size="small">{{ row.is_active ? '启用' : '停用' }}</el-tag></template>
        </el-table-column>
        <el-table-column label="操作" width="200">
          <template #default="{ row }">
            <el-button link type="success" size="small" @click="handleGenerate(row.id)">立即生成</el-button>
            <el-button link type="primary" size="small" @click="editItem(row)">编辑</el-button>
            <el-popconfirm title="确定删除？" @confirm="handleDelete(row.id)">
              <template #reference><el-button link type="danger" size="small">删除</el-button></template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showDialog" :title="editingId ? '编辑' : '新建周期交易'" width="500px" destroy-on-close>
      <el-form :model="form" label-width="80px">
        <el-form-item label="类型">
          <el-radio-group v-model="form.type"><el-radio-button value="expense">支出</el-radio-button><el-radio-button value="income">收入</el-radio-button></el-radio-group>
        </el-form-item>
        <el-form-item label="金额(分)"><el-input-number v-model="form.amount" :min="1" style="width: 100%;" /></el-form-item>
        <el-form-item label="账本">
          <el-select v-model="form.book_id" style="width: 100%;">
            <el-option v-for="b in books" :key="b.id" :label="b.name" :value="b.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="频率">
          <el-select v-model="form.frequency" style="width: 100%;">
            <el-option label="每天" value="daily" /><el-option label="每周" value="weekly" />
            <el-option label="每月" value="monthly" /><el-option label="每年" value="yearly" />
          </el-select>
        </el-form-item>
        <el-form-item label="开始日期"><el-date-picker v-model="form.start_date" type="date" value-format="YYYY-MM-DD" style="width: 100%;" /></el-form-item>
        <el-form-item label="商户"><el-input v-model="form.merchant_name" /></el-form-item>
        <el-form-item label="备注"><el-input v-model="form.description" /></el-form-item>
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
import { getRecurring, createRecurring, updateRecurring, deleteRecurring, generateRecurring } from '@/api/recurring'
import { getBooks } from '@/api/books'
import type { RecurringTransaction, AccountBook } from '@/types'

const loading = ref(false)
const saving = ref(false)
const items = ref<RecurringTransaction[]>([])
const books = ref<AccountBook[]>([])
const showDialog = ref(false)
const editingId = ref<number | null>(null)
const form = reactive({
  type: 'expense', amount: 0, book_id: 0, frequency: 'monthly', start_date: '',
  merchant_name: '', description: '',
})

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

async function load() {
  loading.value = true
  try { items.value = (await getRecurring()).data } finally { loading.value = false }
}

function openCreate() {
  editingId.value = null
  form.type = 'expense'; form.amount = 0; form.book_id = books.value[0]?.id || 0
  form.frequency = 'monthly'; form.start_date = new Date().toISOString().slice(0, 10)
  form.merchant_name = ''; form.description = ''
  showDialog.value = true
}

function editItem(row: RecurringTransaction) {
  editingId.value = row.id; form.type = row.type; form.amount = row.amount
  form.book_id = row.book_id; form.frequency = row.frequency; form.start_date = row.start_date
  form.merchant_name = row.merchant_name || ''; form.description = row.description || ''
  showDialog.value = true
}

async function handleSave() {
  if (!form.amount || !form.start_date || !form.book_id) { ElMessage.warning('请填写金额、账本和开始日期'); return }
  saving.value = true
  try {
    const payload = { type: form.type, amount: form.amount, book_id: form.book_id, frequency: form.frequency,
      start_date: form.start_date, merchant_name: form.merchant_name || undefined, description: form.description || undefined }
    if (editingId.value) { await updateRecurring(editingId.value, payload as any); ElMessage.success('更新成功') }
    else { await createRecurring(payload as any); ElMessage.success('创建成功') }
    showDialog.value = false; editingId.value = null; await load()
  } catch (err: unknown) { ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '保存失败') }
  finally { saving.value = false }
}

async function handleGenerate(id: number) {
  try { await generateRecurring(id); ElMessage.success('已生成'); await load() } catch { ElMessage.error('生成失败') }
}

async function handleDelete(id: number) {
  try { await deleteRecurring(id); ElMessage.success('已删除'); await load() } catch { ElMessage.error('删除失败') }
}

onMounted(async () => {
  await Promise.all([load(), getBooks().then((r) => { books.value = r.data })])
})
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
