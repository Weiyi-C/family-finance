<template>
  <div>
    <div class="page-header">
      <h3>借贷管理</h3>
      <div>
        <el-select v-model="filterType" clearable placeholder="类型" style="width: 100px; margin-right: 8px;" @change="load">
          <el-option label="借出" value="lend" /><el-option label="借入" value="borrow" />
        </el-select>
        <el-select v-model="filterStatus" clearable placeholder="状态" style="width: 100px; margin-right: 8px;" @change="load">
          <el-option label="待还" value="pending" /><el-option label="部分" value="partial" /><el-option label="已清" value="settled" />
        </el-select>
        <el-button type="primary" @click="showDialog = true"><el-icon><Plus /></el-icon> 新建</el-button>
      </div>
    </div>
    <el-card>
      <el-table :data="debts" stripe v-loading="loading">
        <el-table-column prop="person_name" label="对方" width="100" />
        <el-table-column prop="type" label="类型" width="70">
          <template #default="{ row }">
            <el-tag :type="row.type === 'lend' ? 'warning' : 'primary'" size="small">{{ row.type === 'lend' ? '借出' : '借入' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="总额" align="right"><template #default="{ row }">{{ formatMoney(row.amount) }}</template></el-table-column>
        <el-table-column label="剩余" align="right"><template #default="{ row }">{{ formatMoney(row.remaining_amount) }}</template></el-table-column>
        <el-table-column prop="status" label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.status === 'settled' ? 'success' : row.status === 'partial' ? 'warning' : 'danger'" size="small">
              {{ statusMap[row.status] }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="due_date" label="到期" width="110" />
        <el-table-column label="操作" width="180">
          <template #default="{ row }">
            <el-button v-if="row.status !== 'settled'" link type="success" size="small" @click="openRepay(row)">还款</el-button>
            <el-button link type="primary" size="small" @click="editDebt(row)">编辑</el-button>
            <el-popconfirm title="确定删除？" @confirm="handleDelete(row.id)">
              <template #reference><el-button link type="danger" size="small">删除</el-button></template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showDialog" :title="editingId ? '编辑借贷' : '新建借贷'" width="460px" destroy-on-close>
      <el-form :model="form" label-width="80px">
        <el-form-item label="类型">
          <el-radio-group v-model="form.type"><el-radio-button value="lend">借出</el-radio-button><el-radio-button value="borrow">借入</el-radio-button></el-radio-group>
        </el-form-item>
        <el-form-item label="对方"><el-input v-model="form.person_name" /></el-form-item>
        <el-form-item label="金额(元)"><el-input-number v-model="form.amountYuan" :min="1" :precision="2" style="width: 100%;" /></el-form-item>
        <el-form-item label="到期日"><el-date-picker v-model="form.due_date" type="date" value-format="YYYY-MM-DD" style="width: 100%;" /></el-form-item>
        <el-form-item label="备注"><el-input v-model="form.note" type="textarea" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="showRepay" title="还款" width="360px">
      <el-form label-width="60px">
        <el-form-item label="金额(元)"><el-input-number v-model="repayAmount" :min="0.01" :precision="2" style="width: 100%;" /></el-form-item>
        <el-form-item label="备注"><el-input v-model="repayNote" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showRepay = false">取消</el-button>
        <el-button type="primary" @click="handleRepay">确认还款</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Plus } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getDebts, createDebt, updateDebt, deleteDebt, addRepayment } from '@/api/debts'
import type { Debt } from '@/types'

const loading = ref(false)
const saving = ref(false)
const debts = ref<Debt[]>([])
const filterType = ref('')
const filterStatus = ref('')
const showDialog = ref(false)
const editingId = ref<number | null>(null)
const showRepay = ref(false)
const repayDebtId = ref(0)
const repayAmount = ref(0)
const repayNote = ref('')

const statusMap: Record<string, string> = { pending: '待还', partial: '部分', settled: '已清' }
const form = reactive({ type: 'lend', person_name: '', amountYuan: 0, due_date: '', note: '' })

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

async function load() {
  loading.value = true
  try { debts.value = (await getDebts({ type: filterType.value || undefined, status: filterStatus.value || undefined })).data }
  finally { loading.value = false }
}

function editDebt(row: Debt) {
  editingId.value = row.id; form.type = row.type; form.person_name = row.person_name
  form.amountYuan = row.amount / 100; form.due_date = row.due_date || ''; form.note = row.note || ''
  showDialog.value = true
}

async function handleSave() {
  if (!form.person_name || !form.amountYuan) { ElMessage.warning('请填写对方和金额'); return }
  saving.value = true
  try {
    const payload = { type: form.type, person_name: form.person_name, amount: Math.round(form.amountYuan * 100), due_date: form.due_date || undefined, note: form.note || undefined }
    if (editingId.value) { await updateDebt(editingId.value, payload); ElMessage.success('更新成功') }
    else { await createDebt(payload); ElMessage.success('创建成功') }
    showDialog.value = false; editingId.value = null; await load()
  } catch (err: unknown) { ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '保存失败') }
  finally { saving.value = false }
}

function openRepay(row: Debt) { repayDebtId.value = row.id; repayAmount.value = 0; repayNote.value = ''; showRepay.value = true }

async function handleRepay() {
  if (!repayAmount.value) { ElMessage.warning('请填写金额'); return }
  try {
    await addRepayment(repayDebtId.value, { amount: Math.round(repayAmount.value * 100), note: repayNote.value || undefined })
    ElMessage.success('还款成功'); showRepay.value = false; await load()
  } catch { ElMessage.error('还款失败') }
}

async function handleDelete(id: number) {
  try { await deleteDebt(id); ElMessage.success('已删除'); await load() } catch { ElMessage.error('删除失败') }
}

onMounted(load)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
