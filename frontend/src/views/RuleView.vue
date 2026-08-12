<template>
  <div>
    <div class="page-header">
      <h3>规则引擎</h3>
      <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon> 新建规则</el-button>
    </div>
    <el-card>
      <el-table :data="rules" stripe v-loading="loading">
        <el-table-column prop="name" label="规则名称" />
        <el-table-column label="来源" width="70">
          <template #default="{ row }">
            <el-tag :type="row.family_id ? 'primary' : 'info'" size="small">{{ row.family_id ? '用户' : '系统' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="类型" width="90">
          <template #default="{ row }">{{ stageMap[row.stage] || row.stage }}</template>
        </el-table-column>
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
            <el-popconfirm v-if="row.family_id" title="确定删除？" @confirm="handleDelete(row.id)">
              <template #reference><el-button link type="danger" size="small">删除</el-button></template>
            </el-popconfirm>
            <el-tooltip v-else content="系统规则不可删除，可停用后创建自定义规则覆盖" placement="top">
              <el-button link type="danger" size="small" disabled>删除</el-button>
            </el-tooltip>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showDialog" :title="editingId ? '编辑规则' : '新建规则'" width="620px" destroy-on-close>
      <el-form :model="form" label-width="80px">
        <el-form-item label="名称"><el-input v-model="form.name" placeholder="如：餐饮-连锁品牌" /></el-form-item>
        <el-form-item label="类型">
          <el-select v-model="form.stage" class="w-full">
            <el-option label="自动分类" value="classify" />
            <el-option label="自动标记" value="tag" />
            <el-option label="后处理" value="process" />
            <el-option label="提醒通知" value="notify" disabled />
          </el-select>
        </el-form-item>
        <el-form-item label="优先级">
          <el-input-number v-model="form.priority" :min="0" :max="100" />
          <span class="text-sm text-muted ml-8">0-100，越大越优先</span>
        </el-form-item>

        <!-- 图形化编辑模式 -->
        <template v-if="!editMode">
          <el-divider>匹配条件</el-divider>
          <el-form-item label="关键词">
            <div class="w-full">
              <div v-for="(kw, i) in form.keywords" :key="i" class="flex items-center gap-8 mb-4">
                <el-input v-model="form.keywords[i]" placeholder="关键词" style="flex:1;" />
                <el-button link type="danger" size="small" @click="form.keywords.splice(i, 1)">删除</el-button>
              </div>
              <el-button size="small" @click="form.keywords.push('')">+ 添加关键词</el-button>
              <div class="text-sm text-muted mt-4">商户名或描述中包含任一关键词即匹配</div>
            </div>
          </el-form-item>

          <el-divider>执行动作</el-divider>
          <el-form-item label="设置分类" v-if="form.stage === 'classify'">
            <el-select v-model="form.actionCategory" clearable filterable placeholder="选择分类" class="w-full">
              <el-option v-for="c in categories" :key="c.id" :label="c.name" :value="c.name" />
            </el-select>
          </el-form-item>
          <el-form-item label="添加标签">
            <div class="w-full">
              <div v-for="(tag, i) in form.actionTags" :key="i" class="flex items-center gap-8 mb-4">
                <el-input v-model="form.actionTags[i]" placeholder="标签名" style="flex:1;" />
                <el-button link type="danger" size="small" @click="form.actionTags.splice(i, 1)">删除</el-button>
              </div>
              <el-button size="small" @click="form.actionTags.push('')">+ 添加标签</el-button>
            </div>
          </el-form-item>
        </template>

        <!-- JSON 编辑模式 -->
        <template v-else>
          <el-form-item label="条件(JSON)">
            <el-input v-model="form.conditionsStr" type="textarea" :rows="3" />
            <div class="text-sm text-muted mt-4">
              格式：{"keywords": ["关键词1", "关键词2"]}
            </div>
          </el-form-item>
          <el-form-item label="动作(JSON)">
            <el-input v-model="form.actionsStr" type="textarea" :rows="3" />
            <div class="text-sm text-muted mt-4">
              格式：{"category_name": "分类名", "tags": ["标签1"]}
            </div>
          </el-form-item>
        </template>

        <el-form-item>
          <el-button size="small" @click="editMode = !editMode">
            {{ editMode ? '切换为图形模式' : '切换为JSON模式' }}
          </el-button>
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
import { getCategoriesFlat } from '@/api/categories'
import type { AutomationRule } from '@/api/rules'
import type { Category } from '@/types'

const stageMap: Record<string, string> = { classify: '自动分类', tag: '自动标记', notify: '提醒通知', process: '后处理' }

const loading = ref(false)
const saving = ref(false)
const rules = ref<AutomationRule[]>([])
const categories = ref<Category[]>([])
const showDialog = ref(false)
const editingId = ref<number | null>(null)
const editMode = ref(false)

const form = reactive({
  name: '', stage: 'classify', priority: 50,
  keywords: [''] as string[], actionCategory: '', actionTags: [] as string[],
  conditionsStr: '{}', actionsStr: '{}',
})

async function load() {
  loading.value = true
  try { rules.value = (await getRules()).data } finally { loading.value = false }
}

function openCreate() {
  editingId.value = null; form.name = ''; form.stage = 'classify'; form.priority = 50
  form.keywords = ['']; form.actionCategory = ''; form.actionTags = []
  form.conditionsStr = '{}'; form.actionsStr = '{}'; editMode.value = false
  showDialog.value = true
}

function editRule(row: AutomationRule) {
  editingId.value = row.id; form.name = row.name; form.stage = row.stage; form.priority = row.priority
  // 解析条件到图形模式
  const cond = row.conditions || {}
  const act = row.actions || {}
  form.keywords = (cond.keywords as string[]) || ['']
  form.actionCategory = (act.category_name as string) || ''
  form.actionTags = (act.tags as string[]) || []
  // JSON 模式
  form.conditionsStr = JSON.stringify(row.conditions)
  form.actionsStr = JSON.stringify(row.actions)
  editMode.value = false
  showDialog.value = true
}

function buildPayload() {
  if (editMode.value) {
    // JSON 模式直接解析
    const conditions = JSON.parse(form.conditionsStr)
    const actions = JSON.parse(form.actionsStr)
    return { conditions, actions }
  }
  // 图形模式构建 JSON
  const conditions: Record<string, unknown> = {}
  const actions: Record<string, unknown> = {}
  const kw = form.keywords.filter((k) => k.trim())
  if (kw.length) conditions.keywords = kw
  if (form.actionCategory) actions.category_name = form.actionCategory
  const tags = form.actionTags.filter((t) => t.trim())
  if (tags.length) actions.tags = tags
  return { conditions, actions }
}

async function handleSave() {
  if (!form.name) { ElMessage.warning('请填写名称'); return }
  let payload: { conditions: Record<string, unknown>; actions: Record<string, unknown> }
  try { payload = buildPayload() }
  catch { ElMessage.error('JSON格式错误'); return }
  saving.value = true
  try {
    const data = { name: form.name, stage: form.stage, priority: form.priority, ...payload }
    if (editingId.value) { await updateRule(editingId.value, data); ElMessage.success('更新成功') }
    else { await createRule(data); ElMessage.success('创建成功') }
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

onMounted(async () => {
  await Promise.all([load(), getCategoriesFlat().then((r) => { categories.value = r.data })])
})
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
