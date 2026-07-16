<template>
  <div>
    <div class="page-header">
      <h3>分类管理</h3>
      <div>
        <el-radio-group v-model="filterType" @change="load">
          <el-radio-button value="">全部</el-radio-button>
          <el-radio-button value="expense">支出</el-radio-button>
          <el-radio-button value="income">收入</el-radio-button>
        </el-radio-group>
        <el-button type="primary" style="margin-left: 12px;" @click="showDialog = true"><el-icon><Plus /></el-icon> 新建</el-button>
      </div>
    </div>
    <el-card>
      <el-tree
        :data="treeData"
        node-key="id"
        default-expand-all
        :props="{ children: 'children', label: 'name' }"
      >
        <template #default="{ data }">
          <div class="tree-node">
            <span>
              <el-tag :type="data.type === 'expense' ? 'danger' : 'success'" size="small" style="margin-right: 8px;">
                {{ data.type === 'expense' ? '支出' : '收入' }}
              </el-tag>
              {{ data.name }}
              <el-tag v-if="!data.family_id" size="small" type="info" style="margin-left: 8px;">系统</el-tag>
            </span>
            <span class="tree-actions">
              <el-button link type="primary" size="small" @click.stop="addChild(data)">添加子分类</el-button>
              <el-button v-if="data.family_id" link type="primary" size="small" @click.stop="editCategory(data)">编辑</el-button>
              <el-popconfirm v-if="data.family_id" title="确定删除？" @confirm="handleDelete(data.id)">
                <template #reference><el-button link type="danger" size="small" @click.stop>删除</el-button></template>
              </el-popconfirm>
            </span>
          </div>
        </template>
      </el-tree>
    </el-card>

    <el-dialog v-model="showDialog" :title="editingId ? '编辑分类' : '新建分类'" width="400px" destroy-on-close>
      <el-form :model="form" label-width="80px">
        <el-form-item label="名称"><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="类型">
          <el-select v-model="form.type" style="width: 100%;">
            <el-option label="支出" value="expense" /><el-option label="收入" value="income" />
          </el-select>
        </el-form-item>
        <el-form-item label="父分类">
          <el-select v-model="form.parent_id" clearable placeholder="无（一级分类）" style="width: 100%;">
            <el-option v-for="c in flatCategories" :key="c.id" :label="c.name" :value="c.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="图标"><el-input v-model="form.icon" /></el-form-item>
        <el-form-item label="颜色"><el-color-picker v-model="form.color" /></el-form-item>
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
import { getCategories, getCategoriesFlat, createCategory, updateCategory, deleteCategory } from '@/api/categories'
import type { Category } from '@/types'

const loading = ref(false)
const saving = ref(false)
const treeData = ref<Category[]>([])
const flatCategories = ref<Category[]>([])
const filterType = ref('')
const showDialog = ref(false)
const editingId = ref<number | null>(null)

const form = reactive({
  name: '', type: 'expense', parent_id: null as number | null, icon: '', color: '',
})

async function load() {
  loading.value = true
  try {
    const [treeRes, flatRes] = await Promise.all([
      getCategories(filterType.value || undefined),
      getCategoriesFlat(filterType.value || undefined),
    ])
    treeData.value = treeRes.data
    flatCategories.value = flatRes.data.filter((c) => c.level === 1)
  } finally { loading.value = false }
}

function addChild(parent: Category) {
  editingId.value = null
  form.name = ''
  form.type = parent.type
  form.parent_id = parent.id
  form.icon = ''
  form.color = ''
  showDialog.value = true
}

function editCategory(data: Category) {
  editingId.value = data.id
  form.name = data.name
  form.type = data.type
  form.parent_id = data.parent_id
  form.icon = data.icon || ''
  form.color = data.color || ''
  showDialog.value = true
}

async function handleSave() {
  if (!form.name) { ElMessage.warning('请填写名称'); return }
  saving.value = true
  try {
    const payload = { ...form, parent_id: form.parent_id || undefined, icon: form.icon || undefined, color: form.color || undefined }
    if (editingId.value) {
      await updateCategory(editingId.value, payload)
      ElMessage.success('更新成功')
    } else {
      await createCategory(payload)
      ElMessage.success('创建成功')
    }
    showDialog.value = false
    editingId.value = null
    await load()
  } catch (err: unknown) {
    ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '保存失败')
  } finally { saving.value = false }
}

async function handleDelete(id: number) {
  try { await deleteCategory(id); ElMessage.success('已删除'); await load() } catch { ElMessage.error('删除失败') }
}

onMounted(load)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
.tree-node { display: flex; justify-content: space-between; align-items: center; width: 100%; padding-right: 8px; }
.tree-actions { margin-left: 16px; }
</style>
