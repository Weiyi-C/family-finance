<template>
  <div>
    <div class="page-header">
      <h3>账本管理</h3>
      <el-button type="primary" @click="showDialog = true"><el-icon><Plus /></el-icon> 新建账本</el-button>
    </div>
    <el-card>
      <el-table :data="books" stripe v-loading="loading">
        <el-table-column prop="name" label="名称" />
        <el-table-column prop="description" label="描述" />
        <el-table-column prop="is_default" label="默认" width="70">
          <template #default="{ row }"><el-tag v-if="row.is_default" size="small">默认</el-tag></template>
        </el-table-column>
        <el-table-column prop="is_archived" label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.is_archived ? 'info' : 'success'" size="small">{{ row.is_archived ? '已归档' : '使用中' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="140">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="editBook(row)">编辑</el-button>
            <el-popconfirm v-if="!row.is_default" title="确定归档？" @confirm="handleArchive(row.id)">
              <template #reference><el-button link type="danger" size="small">归档</el-button></template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showDialog" :title="editingId ? '编辑账本' : '新建账本'" width="400px" destroy-on-close>
      <el-form :model="form" label-width="80px">
        <el-form-item label="名称"><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="描述"><el-input v-model="form.description" type="textarea" /></el-form-item>
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
import { getBooks, createBook, updateBook, deleteBook } from '@/api/books'
import type { AccountBook } from '@/types'

const loading = ref(false)
const saving = ref(false)
const books = ref<AccountBook[]>([])
const showDialog = ref(false)
const editingId = ref<number | null>(null)
const form = reactive({ name: '', description: '' })

async function load() {
  loading.value = true
  try { books.value = (await getBooks(true)).data } finally { loading.value = false }
}

function editBook(row: AccountBook) {
  editingId.value = row.id; form.name = row.name; form.description = row.description || ''; showDialog.value = true
}

async function handleSave() {
  if (!form.name) { ElMessage.warning('请填写名称'); return }
  saving.value = true
  try {
    const payload = { name: form.name, description: form.description || undefined }
    if (editingId.value) { await updateBook(editingId.value, payload); ElMessage.success('更新成功') }
    else { await createBook(payload); ElMessage.success('创建成功') }
    showDialog.value = false; editingId.value = null; await load()
  } catch (err: unknown) { ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '保存失败') }
  finally { saving.value = false }
}

async function handleArchive(id: number) {
  try { await deleteBook(id); ElMessage.success('已归档'); await load() } catch { ElMessage.error('操作失败') }
}

onMounted(load)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
