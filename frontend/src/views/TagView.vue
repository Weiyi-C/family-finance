<template>
  <div>
    <div class="page-header">
      <h3>标签管理</h3>
      <el-button type="primary" @click="showDialog = true"><el-icon><Plus /></el-icon> 新建标签</el-button>
    </div>
    <el-card>
      <el-table :data="tags" stripe v-loading="loading">
        <el-table-column prop="name" label="名称" />
        <el-table-column prop="color" label="颜色" width="100">
          <template #default="{ row }">
            <el-tag :color="row.color" v-if="row.color" size="small" style="color: #fff;">{{ row.color }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="usage_count" label="使用次数" width="100" />
        <el-table-column label="操作" width="140">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="editTag(row)">编辑</el-button>
            <el-popconfirm title="确定删除？" @confirm="handleDelete(row.id)">
              <template #reference><el-button link type="danger" size="small">删除</el-button></template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showDialog" :title="editingId ? '编辑标签' : '新建标签'" width="360px" destroy-on-close>
      <el-form :model="form" label-width="60px">
        <el-form-item label="名称"><el-input v-model="form.name" /></el-form-item>
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
import { getTags, createTag, updateTag, deleteTag } from '@/api/tags'
import type { Tag } from '@/types'

const loading = ref(false)
const saving = ref(false)
const tags = ref<Tag[]>([])
const showDialog = ref(false)
const editingId = ref<number | null>(null)
const form = reactive({ name: '', color: '' })

async function load() {
  loading.value = true
  try { tags.value = (await getTags()).data } finally { loading.value = false }
}

function editTag(row: Tag) {
  editingId.value = row.id; form.name = row.name; form.color = row.color || ''; showDialog.value = true
}

async function handleSave() {
  if (!form.name) { ElMessage.warning('请填写名称'); return }
  saving.value = true
  try {
    const payload = { name: form.name, color: form.color || undefined }
    if (editingId.value) { await updateTag(editingId.value, payload); ElMessage.success('更新成功') }
    else { await createTag(payload); ElMessage.success('创建成功') }
    showDialog.value = false; editingId.value = null; await load()
  } catch (err: unknown) { ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '保存失败') }
  finally { saving.value = false }
}

async function handleDelete(id: number) {
  try { await deleteTag(id); ElMessage.success('已删除'); await load() } catch { ElMessage.error('删除失败') }
}

onMounted(load)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
