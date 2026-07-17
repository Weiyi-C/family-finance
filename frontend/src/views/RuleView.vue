<template>
  <div>
    <div class="page-header">
      <h3>规则引擎</h3>
      <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon> 新建规则</el-button>
    </div>
    <el-card>
      <el-table :data="rules" stripe v-loading="loading">
        <el-table-column prop="name" label="规则名称" />
        <el-table-column prop="stage" label="阶段" width="100" />
        <el-table-column prop="priority" label="优先级" width="80" />
        <el-table-column prop="hit_count" label="命中次数" width="90" />
        <el-table-column prop="is_active" label="状态" width="70">
          <template #default="{ row }"><el-tag :type="row.is_active ? 'success' : 'info'" size="small">{{ row.is_active ? '启用' : '停用' }}</el-tag></template>
        </el-table-column>
        <el-table-column label="操作" width="180">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="editRule(row)">编辑</el-button>
            <el-button link :type="row.is_active ? 'warning' : 'success'" size="small" @click="toggleActive(row)">
              {{ row.is_active ? '停用' : '启用' }}
            </el-button>
            <el-popconfirm title="确定删除？" @confirm="handleDelete(row.id)">
              <template #reference><el-button link type="danger" size="small">删除</el-button></template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showDialog" :title="editingId ? '编辑规则' : '新建规则'" width="560px" destroy-on-close>
      <el-form :model="form" label-width="80px">
        <el-form-item label="名称"><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="阶段">
          <el-select v-model="form.stage" style="width: 100%;">
            <el-option label="分类" value="classify" /><el-option label="标记" value="tag" /><el-option label="通知" value="notify" />
          </el-select>
        </el-form-item>
        <el-form-item label="优先级"><el-input-number v-model="form.priority" :min="0" :max="100" /></el-form-item>
        <el-form-item label="条件(JSON)">
          <el-input v-model="form.conditionsStr" type="textarea" :rows="3" placeholder='{"merchant":"肯德基"}' />
        </el-form-item>
        <el-form-item label="动作(JSON)">
          <el-input v-model="form.actionsStr" type="textarea" :rows="3" placeholder='{"category_id":1}' />
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
import { getRules, createRule, updateRule, deleteRule } from '@/api/rules'
import type { AutomationRule } from '@/api/rules'

const loading = ref(false)
const saving = ref(false)
const rules = ref<AutomationRule[]>([])
const showDialog = ref(false)
const editingId = ref<number | null>(null)
const form = reactive({ name: '', stage: 'classify', priority: 0, conditionsStr: '{}', actionsStr: '{}' })

async function load() {
  loading.value = true
  try { rules.value = (await getRules()).data } finally { loading.value = false }
}

function openCreate() {
  editingId.value = null; form.name = ''; form.stage = 'classify'; form.priority = 0
  form.conditionsStr = '{}'; form.actionsStr = '{}'; showDialog.value = true
}

function editRule(row: AutomationRule) {
  editingId.value = row.id; form.name = row.name; form.stage = row.stage; form.priority = row.priority
  form.conditionsStr = JSON.stringify(row.conditions); form.actionsStr = JSON.stringify(row.actions); showDialog.value = true
}

async function handleSave() {
  if (!form.name) { ElMessage.warning('请填写名称'); return }
  let conditions: Record<string, unknown>, actions: Record<string, unknown>
  try { conditions = JSON.parse(form.conditionsStr); actions = JSON.parse(form.actionsStr) }
  catch { ElMessage.error('JSON格式错误'); return }
  saving.value = true
  try {
    const payload = { name: form.name, stage: form.stage, priority: form.priority, conditions, actions }
    if (editingId.value) { await updateRule(editingId.value, payload); ElMessage.success('更新成功') }
    else { await createRule(payload); ElMessage.success('创建成功') }
    showDialog.value = false; editingId.value = null; await load()
  } catch (err: unknown) { ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '保存失败') }
  finally { saving.value = false }
}

async function toggleActive(row: AutomationRule) {
  try { await updateRule(row.id, { is_active: !row.is_active }); await load() } catch { ElMessage.error('操作失败') }
}

async function handleDelete(id: number) {
  try { await deleteRule(id); ElMessage.success('已删除'); await load() } catch { ElMessage.error('删除失败') }
}

onMounted(load)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
