<template>
  <div>
    <div class="page-header">
      <h3>账单导入</h3>
      <div>
        <el-button type="success" @click="showExportDialog = true"><el-icon><Upload /></el-icon> 导出数据</el-button>
        <el-button type="primary" @click="showImportDialog = true" style="margin-left: 8px;"><el-icon><Plus /></el-icon> 新建导入</el-button>
      </div>
    </div>
    <el-card>
      <el-table :data="imports" stripe v-loading="loading">
        <el-table-column prop="source" label="来源" width="100" />
        <el-table-column prop="file_format" label="格式" width="70" />
        <el-table-column prop="status" label="状态" width="80">
          <template #default="{ row }"><el-tag size="small">{{ row.status }}</el-tag></template>
        </el-table-column>
        <el-table-column prop="total_rows" label="总行数" width="80" />
        <el-table-column prop="parsed_count" label="已解析" width="80" />
        <el-table-column prop="matched_count" label="已匹配" width="80" />
        <el-table-column label="操作" width="140">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="viewItems(row.id)">查看明细</el-button>
            <el-popconfirm title="确定删除？" @confirm="handleDelete(row.id)">
              <template #reference><el-button link type="danger" size="small">删除</el-button></template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showImportDialog" title="新建导入" width="500px" destroy-on-close>
      <el-form :model="importForm" label-width="80px">
        <el-form-item label="账本">
          <el-select v-model="importForm.book_id" style="width: 100%;">
            <el-option v-for="b in books" :key="b.id" :label="b.name" :value="b.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="来源">
          <el-select v-model="importForm.source" style="width: 100%;">
            <el-option label="支付宝" value="alipay" /><el-option label="微信" value="wechat" /><el-option label="银行" value="bank" /><el-option label="其他" value="other" />
          </el-select>
        </el-form-item>
        <el-form-item label="数据(JSON)">
          <el-input v-model="importForm.itemsStr" type="textarea" :rows="6" placeholder='[{"amount":3500,"merchant":"超市","time":"2026-07-17"}]' />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showImportDialog = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleImport">导入</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="showItemsDialog" title="导入明细" width="600px">
      <el-table :data="items" stripe size="small">
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column label="解析金额" width="100">
          <template #default="{ row }">{{ row.parsed_amount ? `¥${(row.parsed_amount / 100).toFixed(2)}` : '-' }}</template>
        </el-table-column>
        <el-table-column prop="parsed_merchant" label="商户" />
        <el-table-column prop="action" label="操作" width="80" />
        <el-table-column prop="matched_txn_id" label="匹配交易" width="90" />
      </el-table>
    </el-dialog>

    <el-dialog v-model="showExportDialog" title="导出数据" width="400px">
      <el-form label-width="80px">
        <el-form-item label="类型">
          <el-radio-group v-model="exportType">
            <el-radio-button value="transactions">交易</el-radio-button>
            <el-radio-button value="accounts">账户</el-radio-button>
            <el-radio-button value="categories">分类</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="格式">
          <el-radio-group v-model="exportFormat">
            <el-radio-button value="csv">CSV</el-radio-button>
            <el-radio-button value="json">JSON</el-radio-button>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showExportDialog = false">取消</el-button>
        <el-button type="primary" @click="handleExport">导出</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Plus, Upload } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getImports, createImport, getImportItems, deleteImport } from '@/api/imports'
import { exportTransactions, exportAccounts, exportCategories } from '@/api/exports'
import { getBooks } from '@/api/books'
import type { BillImport, BillImportItem } from '@/api/imports'
import type { AccountBook } from '@/types'

const loading = ref(false)
const saving = ref(false)
const imports = ref<BillImport[]>([])
const items = ref<BillImportItem[]>([])
const books = ref<AccountBook[]>([])
const showImportDialog = ref(false)
const showItemsDialog = ref(false)
const showExportDialog = ref(false)
const exportType = ref('transactions')
const exportFormat = ref('csv')
const importForm = reactive({ book_id: 0, source: 'alipay', itemsStr: '[]' })

async function load() {
  loading.value = true
  try { imports.value = (await getImports()).data } finally { loading.value = false }
}

async function handleImport() {
  let itemsArr: Record<string, unknown>[]
  try { itemsArr = JSON.parse(importForm.itemsStr) } catch { ElMessage.error('JSON格式错误'); return }
  saving.value = true
  try {
    await createImport({ book_id: importForm.book_id, source: importForm.source, items: itemsArr })
    ElMessage.success('导入成功'); showImportDialog.value = false; await load()
  } catch (err: unknown) { ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '导入失败') }
  finally { saving.value = false }
}

async function viewItems(importId: number) {
  try { items.value = (await getImportItems(importId)).data; showItemsDialog.value = true }
  catch { ElMessage.error('加载失败') }
}

async function handleDelete(id: number) {
  try { await deleteImport(id); ElMessage.success('已删除'); await load() } catch { ElMessage.error('删除失败') }
}

async function handleExport() {
  try {
    let res: { data: Blob }
    if (exportType.value === 'transactions') res = await exportTransactions(exportFormat.value as 'csv' | 'json')
    else if (exportType.value === 'accounts') res = await exportAccounts()
    else res = await exportCategories()
    const url = URL.createObjectURL(res.data)
    const a = document.createElement('a'); a.href = url
    a.download = `${exportType.value}.${exportFormat.value}`; a.click(); URL.revokeObjectURL(url)
    ElMessage.success('导出成功'); showExportDialog.value = false
  } catch { ElMessage.error('导出失败') }
}

onMounted(async () => {
  await Promise.all([load(), getBooks().then((r) => { books.value = r.data; if (books.value.length) importForm.book_id = books.value[0].id })])
})
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
