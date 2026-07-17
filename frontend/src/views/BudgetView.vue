<template>
  <div>
    <div class="page-header">
      <h3>预算管理</h3>
      <div>
        <el-date-picker v-model="month" type="month" value-format="YYYY-MM" @change="load" style="width: 160px; margin-right: 12px;" />
        <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon> 新建预算</el-button>
      </div>
    </div>
    <el-card>
      <el-table :data="budgets" stripe v-loading="loading">
        <el-table-column prop="category_id" label="分类" width="120">
          <template #default="{ row }">{{ row.category_id ? `分类${row.category_id}` : '全部' }}</template>
        </el-table-column>
        <el-table-column prop="period" label="周期" width="80" />
        <el-table-column label="预算金额" align="right" width="130">
          <template #default="{ row }">{{ formatMoney(row.amount) }}</template>
        </el-table-column>
        <el-table-column label="已使用" align="right" width="130">
          <template #default="{ row }">
            <span v-if="row._usage">{{ formatMoney(row._usage.spent) }}</span>
            <span v-else class="text-muted">-</span>
          </template>
        </el-table-column>
        <el-table-column label="进度" width="200">
          <template #default="{ row }">
            <el-progress v-if="row._usage" :percentage="Math.min(Math.round(row._usage.usage_rate * 100), 100)"
              :status="row._usage.is_over ? 'exception' : row._usage.usage_rate >= row.alert_threshold ? 'warning' : ''" />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="140">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="editBudget(row)">编辑</el-button>
            <el-popconfirm title="确定删除？" @confirm="handleDelete(row.id)">
              <template #reference><el-button link type="danger" size="small">删除</el-button></template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showDialog" :title="editingId ? '编辑预算' : '新建预算'" width="460px" destroy-on-close>
      <el-form :model="form" label-width="80px">
        <el-form-item label="分类">
          <el-select v-model="form.category_id" clearable placeholder="全部分类" style="width: 100%;">
            <el-option v-for="c in categories" :key="c.id" :label="c.name" :value="c.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="金额(分)"><el-input-number v-model="form.amount" :min="1" style="width: 100%;" /></el-form-item>
        <el-form-item label="周期">
          <el-select v-model="form.period" style="width: 100%;">
            <el-option label="月度" value="monthly" /><el-option label="每周" value="weekly" /><el-option label="年度" value="yearly" />
          </el-select>
        </el-form-item>
        <el-form-item label="年份"><el-input-number v-model="form.year" :min="2024" :max="2030" /></el-form-item>
        <el-form-item label="月份" v-if="form.period === 'monthly'"><el-input-number v-model="form.month" :min="1" :max="12" /></el-form-item>
        <el-form-item label="滚转">
          <el-switch v-model="form.rollover" />
        </el-form-item>
        <el-form-item label="预警阈值">
          <el-slider v-model="form.alertPct" :min="50" :max="100" :format-tooltip="(v: number) => `${v}%`" />
        </el-form-item>
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
import { getBudgets, createBudget, updateBudget, deleteBudget, getBudgetUsage } from '@/api/budgets'
import { getCategoriesFlat } from '@/api/categories'
import type { Budget, Category } from '@/types'

const loading = ref(false)
const saving = ref(false)
const budgets = ref<(Budget & { _usage?: { spent: number; usage_rate: number; is_over: boolean } })[]>([])
const categories = ref<Category[]>([])
const now = new Date()
const month = ref(`${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`)
const showDialog = ref(false)
const editingId = ref<number | null>(null)

const form = reactive({
  category_id: null as number | null, amount: 0, period: 'monthly',
  year: now.getFullYear(), month: now.getMonth() + 1, rollover: false, alertPct: 80,
})

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

async function load() {
  loading.value = true
  try {
    const [y, m] = month.value.split('-').map(Number)
    const res = await getBudgets({ year: y, month: m })
    budgets.value = res.data
    for (const b of budgets.value) {
      try {
        const u = await getBudgetUsage(b.id)
        b._usage = { spent: u.data.spent, usage_rate: u.data.usage_rate, is_over: u.data.is_over }
      } catch { /* ignore */ }
    }
  } finally { loading.value = false }
}

function openCreate() {
  editingId.value = null
  form.category_id = null; form.amount = 0; form.period = 'monthly'
  form.year = now.getFullYear(); form.month = now.getMonth() + 1
  form.rollover = false; form.alertPct = 80
  showDialog.value = true
}

function editBudget(row: Budget) {
  editingId.value = row.id
  form.category_id = row.category_id; form.amount = row.amount; form.period = row.period
  form.year = row.year; form.month = row.month || now.getMonth() + 1
  form.rollover = row.rollover; form.alertPct = Math.round(row.alert_threshold * 100)
  showDialog.value = true
}

async function handleSave() {
  if (!form.amount) { ElMessage.warning('请填写金额'); return }
  saving.value = true
  try {
    const payload = {
      amount: form.amount, period: form.period, category_id: form.category_id || undefined,
      year: form.year, month: form.month, rollover: form.rollover, alert_threshold: form.alertPct / 100,
    }
    if (editingId.value) {
      await updateBudget(editingId.value, payload as any); ElMessage.success('更新成功')
    } else {
      await createBudget(payload as any); ElMessage.success('创建成功')
    }
    showDialog.value = false; editingId.value = null; await load()
  } catch (err: unknown) {
    ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '保存失败')
  } finally { saving.value = false }
}

async function handleDelete(id: number) {
  try { await deleteBudget(id); ElMessage.success('已删除'); await load() } catch { ElMessage.error('删除失败') }
}

onMounted(async () => {
  await Promise.all([load(), getCategoriesFlat().then((r) => { categories.value = r.data })])
})
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
.text-muted { color: #c0c4cc; }
</style>
