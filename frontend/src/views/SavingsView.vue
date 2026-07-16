<template>
  <div>
    <div class="page-header">
      <h3>储蓄目标</h3>
      <el-button type="primary" @click="showDialog = true"><el-icon><Plus /></el-icon> 新建目标</el-button>
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
            <el-progress :percentage="Math.min(Math.round(goal.current_amount / goal.target_amount * 100), 100)"
              :status="goal.status === 'achieved' ? 'success' : ''" :stroke-width="20" />
          </div>
          <div class="goal-detail">
            <span>已存: {{ formatMoney(goal.current_amount) }}</span>
            <span>目标: {{ formatMoney(goal.target_amount) }}</span>
          </div>
          <div class="goal-detail" v-if="goal.deadline">
            <span>截止: {{ goal.deadline }}</span>
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
        <el-form-item label="目标金额(元)"><el-input-number v-model="form.amountYuan" :min="1" :precision="2" style="width: 100%;" /></el-form-item>
        <el-form-item label="截止日期"><el-date-picker v-model="form.deadline" type="date" value-format="YYYY-MM-DD" style="width: 100%;" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="showDeposit" title="存款" width="320px">
      <el-form label-width="60px">
        <el-form-item label="金额(元)"><el-input-number v-model="depositAmount" :min="0.01" :precision="2" style="width: 100%;" /></el-form-item>
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
const form = reactive({ name: '', amountYuan: 0, deadline: '' })

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

async function load() { goals.value = (await getSavings()).data }

function editGoal(row: SavingsGoal) {
  editingId.value = row.id; form.name = row.name; form.amountYuan = row.target_amount / 100; form.deadline = row.deadline || ''; showDialog.value = true
}

async function handleSave() {
  if (!form.name || !form.amountYuan) { ElMessage.warning('请填写名称和金额'); return }
  saving.value = true
  try {
    const payload = { name: form.name, target_amount: Math.round(form.amountYuan * 100), deadline: form.deadline || undefined }
    if (editingId.value) { await updateSavingsGoal(editingId.value, payload); ElMessage.success('更新成功') }
    else { await createSavings(payload); ElMessage.success('创建成功') }
    showDialog.value = false; editingId.value = null; await load()
  } catch (err: unknown) { ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '保存失败') }
  finally { saving.value = false }
}

function openDeposit(id: number) { depositGoalId.value = id; depositAmount.value = 0; showDeposit.value = true }

async function handleDeposit() {
  if (!depositAmount.value) { ElMessage.warning('请填写金额'); return }
  try { await depositSavings(depositGoalId.value, { amount: Math.round(depositAmount.value * 100) }); ElMessage.success('存款成功'); showDeposit.value = false; await load() }
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
