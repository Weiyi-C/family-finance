<template>
  <div>
    <div class="page-header">
      <h3>商户别名</h3>
      <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon> 新建</el-button>
    </div>
    <el-card>
      <el-table :data="aliases" stripe v-loading="loading">
        <el-table-column prop="original_name" label="原始名称" />
        <el-table-column prop="alias_name" label="别名" />
        <el-table-column prop="category_id" label="分类" width="100">
          <template #default="{ row }">{{ row.category_id ? `分类${row.category_id}` : '-' }}</template>
        </el-table-column>
        <el-table-column prop="hit_count" label="命中次数" width="90" />
        <el-table-column prop="is_active" label="状态" width="70">
          <template #default="{ row }"><el-tag :type="row.is_active ? 'success' : 'info'" size="small">{{ row.is_active ? '启用' : '停用' }}</el-tag></template>
        </el-table-column>
        <el-table-column label="操作" width="140">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="editAlias(row)">编辑</el-button>
            <el-popconfirm title="确定删除？" @confirm="handleDelete(row.id)">
              <template #reference><el-button link type="danger" size="small">删除</el-button></template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showDialog" :title="editingId ? '编辑别名' : '新建别名'" width="460px" destroy-on-close>
      <el-form :model="form" label-width="80px">
        <el-form-item label="原始名称"><el-input v-model="form.original_name" :disabled="!!editingId" /></el-form-item>
        <el-form-item label="别名"><el-input v-model="form.alias_name" /></el-form-item>
        <el-form-item label="分类">
          <el-select v-model="form.category_id" clearable placeholder="选择分类" style="width: 100%;">
            <el-option v-for="c in categories" :key="c.id" :label="c.name" :value="c.id" />
          </el-select>
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
import { getAliases, createAlias, updateAlias, deleteAlias } from '@/api/aliases'
import { getCategoriesFlat } from '@/api/categories'
import type { MerchantAlias } from '@/api/aliases'
import type { Category } from '@/types'

const loading = ref(false)
const saving = ref(false)
const aliases = ref<MerchantAlias[]>([])
const categories = ref<Category[]>([])
const showDialog = ref(false)
const editingId = ref<number | null>(null)
const form = reactive({ original_name: '', alias_name: '', category_id: null as number | null })

async function load() {
  loading.value = true
  try { aliases.value = (await getAliases()).data } finally { loading.value = false }
}

function openCreate() {
  editingId.value = null; form.original_name = ''; form.alias_name = ''; form.category_id = null; showDialog.value = true
}

function editAlias(row: MerchantAlias) {
  editingId.value = row.id; form.original_name = row.original_name; form.alias_name = row.alias_name; form.category_id = row.category_id; showDialog.value = true
}

async function handleSave() {
  if (!form.original_name || !form.alias_name) { ElMessage.warning('请填写原始名称和别名'); return }
  saving.value = true
  try {
    const payload = { ...form, category_id: form.category_id || undefined }
    if (editingId.value) { await updateAlias(editingId.value, payload); ElMessage.success('更新成功') }
    else { await createAlias(payload); ElMessage.success('创建成功') }
    showDialog.value = false; editingId.value = null; await load()
  } catch (err: unknown) { ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '保存失败') }
  finally { saving.value = false }
}

async function handleDelete(id: number) {
  try { await deleteAlias(id); ElMessage.success('已删除'); await load() } catch { ElMessage.error('删除失败') }
}

onMounted(async () => {
  await Promise.all([load(), getCategoriesFlat().then((r) => { categories.value = r.data })])
})
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
