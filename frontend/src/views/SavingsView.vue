<template>
  <div>
    <div class="page-header">
      <h3>储蓄目标</h3>
      <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon> 新建目标</el-button>
    </div>
    <el-row :gutter="16">
      <el-col :span="8" v-for="goal in goals" :key="goal.id">
        <el-card shadow="hover" style="margin-bottom: 16px;">
          <div class="goal-header">
            <h4>{{ goal.name }}</h4>
            <el-tag :type="goal.status === 'achieved' ? 'success' : goal.status === 'abandoned' ? 'info' : ''" size="small">
              {{ statusMap[goal.status] }}
            </el-tag>
          </div>
          <div class="goal-progress">
            <el-progress :percentage="Math.min(Math.round(goal.progress * 100), 100)"
              :status="goal.status === 'achieved' ? 'success' : ''" :stroke-width="20" />
          </div>
          <div class="goal-detail">
            <span>已存: {{ formatMoney(goal.current_amount) }}</span>
            <span>目标: {{ formatMoney(goal.target_amount) }}</span>
          </div>
          <div class="goal-detail" v-if="goal.target_date">
            <span>截止: {{ goal.target_date }}</span>
          </div>
          <div class="goal-actions" v-if="goal.status === 'active'">
            <el-button type="success" size="small" @click="openDeposit(goal.id)">存款</el-button>
            <el-button size="small" @click="editGoal(goal)">编辑</el-button>
            <el-popconfirm title="确定放弃？" @confirm="handleAbandon(goal.id)">
              <template #reference><el-button type="danger" size="small">放弃</el-button></template>
            </el-popconfirm>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-dialog v-model="showDialog" :title="editingId ? '编辑目标' : '新建目标'" width="400px" destroy-on-close>
      <el-form :model="form" label-width="80px">
        <el-form-item label="名称"><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="目标金额(分)"><el-input-number v-model="form.target_amount" :min="1" style="width: 100%;" /></el-form-item>
        <el-form-item label="开始日期"><el-date-picker v-model="form.start_date" type="date" value-format="YYYY-MM-DD" style="width: 100%;" /></el-form-item>
        <el-form-item label="截止日期"><el-date-picker v-model="form.target_date" type="date" value-format="YYYY-MM-DD" style="width: 100%;" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="showDeposit" title="存款" width="320px">
      <el-form label-width="80px">
        <el-form-item label="金额(分)"><el-input-number v-model="depositAmount" :min="1" style="width: 100%;" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDeposit = false">取消</el-button>
        <el-button type="primary" @click="handleDeposit">确认</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Plus } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getSavings, createSavings, updateSavingsGoal, depositSavings, abandonSavings } from '@/api/savings'
import type { SavingsGoal } from '@/types'

const saving = ref(false)
const goals = ref<SavingsGoal[]>([])
const showDialog = ref(false)
const editingId = ref<number | null>(null)
const showDeposit = ref(false)
const depositGoalId = ref(0)
const depositAmount = ref(0)
const statusMap: Record<string, string> = { active: '进行中', achieved: '已达成', abandoned: '已放弃' }
const form = reactive({ name: '', target_amount: 0, start_date: new Date().toISOString().slice(0, 10), target_date: '' })

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

async function load() { goals.value = (await getSavings()).data }

function openCreate() {
  editingId.value = null; form.name = ''; form.target_amount = 0
  form.start_date = new Date().toISOString().slice(0, 10); form.target_date = ''
  showDialog.value = true
}

function editGoal(row: SavingsGoal) {
  editingId.value = row.id; form.name = row.name; form.target_amount = row.target_amount
  form.start_date = row.start_date; form.target_date = row.target_date || ''
  showDialog.value = true
}

async function handleSave() {
  if (!form.name || !form.target_amount || !form.start_date) { ElMessage.warning('请填写名称、金额和开始日期'); return }
  saving.value = true
  try {
    const payload = { name: form.name, target_amount: form.target_amount, start_date: form.start_date, target_date: form.target_date || undefined }
    if (editingId.value) { await updateSavingsGoal(editingId.value, payload); ElMessage.success('更新成功') }
    else { await createSavings(payload); ElMessage.success('创建成功') }
    showDialog.value = false; editingId.value = null; await load()
  } catch (err: unknown) { ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '保存失败') }
  finally { saving.value = false }
}

function openDeposit(id: number) { depositGoalId.value = id; depositAmount.value = 0; showDeposit.value = true }

async function handleDeposit() {
  if (!depositAmount.value) { ElMessage.warning('请填写金额'); return }
  try { await depositSavings(depositGoalId.value, { amount: depositAmount.value }); ElMessage.success('存款成功'); showDeposit.value = false; await load() }
  catch { ElMessage.error('存款失败') }
}

async function handleAbandon(id: number) {
  try { await abandonSavings(id); ElMessage.success('已放弃'); await load() } catch { ElMessage.error('操作失败') }
}

onMounted(load)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
.goal-header { display: flex; justify-content: space-between; align-items: center; }
.goal-header h4 { margin: 0; }
.goal-progress { margin: 16px 0; }
.goal-detail { display: flex; justify-content: space-between; font-size: 13px; color: #909399; margin-bottom: 8px; }
.goal-actions { display: flex; gap: 8px; margin-top: 12px; }
</style>
