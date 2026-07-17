<template>
  <div>
    <div class="page-header">
      <h3>账单导入</h3>
      <div>
        <el-button type="success" @click="showExportDialog = true"><el-icon><Upload /></el-icon> 导出数据</el-button>
        <el-button type="primary" @click="showImportDialog = true" style="margin-left: 8px;"><el-icon><Plus /></el-icon> 导入账单</el-button>
      </div>
    </div>
    <el-card>
      <el-table :data="imports" stripe v-loading="loading">
        <el-table-column prop="source" label="来源" width="100">
          <template #default="{ row }">{{ sourceMap[row.source] || row.source }}</template>
        </el-table-column>
        <el-table-column prop="file_format" label="格式" width="70" />
        <el-table-column prop="status" label="状态" width="80">
          <template #default="{ row }"><el-tag :type="statusType[row.status]" size="small">{{ statusMap[row.status] || row.status }}</el-tag></template>
        </el-table-column>
        <el-table-column prop="total_rows" label="总行数" width="80" />
        <el-table-column prop="parsed_count" label="已解析" width="80" />
        <el-table-column prop="new_count" label="已导入" width="80" />
        <el-table-column prop="created_at" label="时间" width="170">
          <template #default="{ row }">{{ row.created_at ? new Date(row.created_at).toLocaleString('zh-CN') : '' }}</template>
        </el-table-column>
        <el-table-column label="操作" width="180">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="viewItems(row.id)">查看明细</el-button>
            <el-popconfirm title="确定删除？" @confirm="handleDelete(row.id)">
              <template #reference><el-button link type="danger" size="small">删除</el-button></template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 导入对话框 -->
    <el-dialog v-model="showImportDialog" title="导入账单" width="700px" destroy-on-close @close="resetImport">
      <!-- 第一步：上传文件 -->
      <div v-if="step === 1">
        <el-form label-width="80px">
          <el-form-item label="账本">
            <el-select v-model="importForm.book_id" style="width: 100%;">
              <el-option v-for="b in books" :key="b.id" :label="b.name" :value="b.id" />
            </el-select>
          </el-form-item>
          <el-form-item label="来源">
            <el-select v-model="importForm.source" style="width: 100%;">
              <el-option label="自动识别" value="auto" />
              <el-option label="支付宝" value="alipay" />
              <el-option label="微信" value="wechat" />
            </el-select>
          </el-form-item>
          <el-form-item label="账单文件">
            <el-upload
              :auto-upload="false"
              :limit="1"
              :on-change="handleFileChange"
              accept=".csv,.xlsx,.xls"
              drag
            >
              <el-icon style="font-size: 40px; color: #c0c4cc;"><Upload /></el-icon>
              <div style="color: #909399;">拖拽文件到此处，或<em style="color: #409eff;">点击上传</em></div>
              <template #tip>
                <div style="color: #909399; font-size: 12px;">支持支付宝/微信导出的 CSV 或 Excel 文件</div>
              </template>
            </el-upload>
          </el-form-item>
        </el-form>
      </div>

      <!-- 第二步：配置账户映射 -->
      <div v-if="step === 2">
        <el-alert :title="`解析完成：${uploadResult?.parsed_count}条记录`" type="success" show-icon style="margin-bottom: 16px;">
          <template #default>
            <span v-if="uploadResult?.skipped_duplicate">，跳过 {{ uploadResult.skipped_duplicate }} 条重复记录</span>
          </template>
        </el-alert>

        <!-- 默认账户 -->
        <el-card style="margin-bottom: 16px;">
          <template #header><span>默认资金来源</span></template>
          <p style="color: #909399; font-size: 13px; margin-bottom: 12px;">
            选择一个默认账户，用于没有明确支付方式的交易。您也可以为每种支付方式单独指定账户。
          </p>
          <el-select v-model="defaultAccountId" placeholder="选择默认账户" style="width: 100%;" clearable>
            <el-option v-for="a in accounts" :key="a.id" :label="a.name" :value="a.id" />
            <el-option :value="0" label="不指定账户（稍后手动分配）" />
          </el-select>
        </el-card>

        <!-- 支付方式映射 -->
        <el-card v-if="uploadResult?.meta?.detected_methods?.length" style="margin-bottom: 16px;">
          <template #header><span>支付方式 → 账户映射</span></template>
          <p style="color: #909399; font-size: 13px; margin-bottom: 12px;">
            系统检测到以下支付方式，请为每种方式选择对应的资金来源账户。
          </p>
          <div v-for="method in uploadResult.meta.detected_methods" :key="method" style="display: flex; align-items: center; gap: 12px; margin-bottom: 12px;">
            <span style="width: 120px; font-weight: 500;">{{ method }}:</span>
            <el-select v-model="methodAccountMap[method]" placeholder="选择账户" style="flex: 1;" clearable>
              <el-option v-for="a in accounts" :key="a.id" :label="a.name" :value="a.id" />
            </el-select>
            <el-button size="small" type="primary" link @click="openCreateAccount(method)">新建账户</el-button>
          </div>
        </el-card>

        <!-- 支付宝没有明确支付方式的提示 -->
        <el-card v-if="uploadResult?.source === 'alipay' && !uploadResult?.meta?.has_payment_method" style="margin-bottom: 16px;">
          <template #header><span>提示</span></template>
          <el-alert title="支付宝标准账单不包含每笔交易的具体扣款渠道" type="info" :closable="false">
            <template #default>
              <p>支付宝余额、花呗、余额宝、绑定的银行卡等都通过支付宝扣款，但账单中不会显示具体使用了哪个。</p>
              <p style="margin-top: 8px;">建议：</p>
              <ul style="margin-top: 4px;">
                <li>如果大部分交易使用花呗，选择"花呗"作为默认账户</li>
                <li>如果大部分交易使用余额，选择"支付宝余额"作为默认账户</li>
                <li>导入后可以在交易列表中手动修改个别交易的账户</li>
              </ul>
            </template>
          </el-alert>
        </el-card>

        <!-- 预览 -->
        <el-card>
          <template #header><span>预览（前{{ uploadResult?.preview?.length || 0 }}条）</span></template>
          <el-table :data="uploadResult?.preview || []" stripe size="small" max-height="300">
            <el-table-column prop="transaction_time" label="时间" width="160" />
            <el-table-column prop="merchant" label="商户" min-width="120" />
            <el-table-column prop="description" label="商品" min-width="150" show-overflow-tooltip />
            <el-table-column label="金额" align="right" width="100">
              <template #default="{ row }">{{ formatMoney(row.amount) }}</template>
            </el-table-column>
            <el-table-column prop="type" label="类型" width="70">
              <template #default="{ row }"><el-tag :type="row.type === 'expense' ? 'danger' : 'success'" size="small">{{ row.type === 'expense' ? '支出' : '收入' }}</el-tag></template>
            </el-table-column>
            <el-table-column label="支付方式" width="120">
              <template #default="{ row }">
                <span v-if="row.payment_method">{{ row.payment_method }}</span>
                <span v-else style="color: #c0c4cc;">{{ defaultAccountId ? accounts.find(a => a.id === defaultAccountId)?.name : '待分配' }}</span>
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </div>

      <template #footer>
        <el-button @click="showImportDialog = false">取消</el-button>
        <el-button v-if="step === 1" type="primary" :loading="uploading" @click="handleUpload" :disabled="!selectedFile">上传解析</el-button>
        <el-button v-if="step === 2" @click="step = 1">上一步</el-button>
        <el-button v-if="step === 2" type="success" :loading="confirming" @click="handleConfirmImport">确认导入</el-button>
      </template>
    </el-dialog>

    <!-- 新建账户对话框 -->
    <el-dialog v-model="showAccountDialog" title="新建账户" width="500px" append-to-body destroy-on-close>
      <el-form :model="accountForm" label-width="80px">
        <el-form-item label="类型">
          <el-select v-model="accountForm.type_code" style="width: 100%;" @change="onTypeChange">
            <el-option-group v-for="group in templateGroups" :key="group.name" :label="group.name">
              <el-option v-for="t in group.templates" :key="t.type_code" :label="`${t.icon} ${t.name}`" :value="t.type_code" />
            </el-option-group>
          </el-select>
        </el-form-item>
        <el-form-item label="名称"><el-input v-model="accountForm.name" /></el-form-item>
        <el-form-item label="银行" v-if="needBank">
          <el-select v-model="accountForm.bank_name" filterable placeholder="选择银行" style="width: 100%;">
            <el-option v-for="b in banks" :key="b.id" :label="b.name" :value="b.name" />
          </el-select>
        </el-form-item>
        <el-form-item label="卡号后四位" v-if="needCard"><el-input v-model="accountForm.card_tail" maxlength="4" /></el-form-item>
        <el-form-item label="信用额度(元)" v-if="needCreditLimit"><el-input-number v-model="accountForm.credit_limit_yuan" :min="0" :precision="2" style="width: 100%;" /></el-form-item>
        <el-form-item label="账单日" v-if="needBillingDay"><el-input-number v-model="accountForm.billing_day" :min="1" :max="28" /></el-form-item>
        <el-form-item label="还款日" v-if="needDueDay"><el-input-number v-model="accountForm.due_day" :min="1" :max="28" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showAccountDialog = false">取消</el-button>
        <el-button type="primary" :loading="savingAccount" @click="handleCreateAccount">创建</el-button>
      </template>
    </el-dialog>

    <!-- 明细对话框 -->
    <el-dialog v-model="showItemsDialog" title="导入明细" width="600px">
      <el-table :data="items" stripe size="small">
        <el-table-column label="金额" width="100">
          <template #default="{ row }">{{ row.parsed_amount ? formatMoney(row.parsed_amount) : '-' }}</template>
        </el-table-column>
        <el-table-column prop="parsed_merchant" label="商户" />
        <el-table-column prop="action" label="状态" width="80">
          <template #default="{ row }"><el-tag size="small">{{ actionMap[row.action] || row.action }}</el-tag></template>
        </el-table-column>
      </el-table>
    </el-dialog>

    <!-- 导出对话框 -->
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
import { ref, reactive, computed, onMounted } from 'vue'
import { Plus, Upload } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getImports, getImportItems, deleteImport } from '@/api/imports'
import { getAccounts, createAccount } from '@/api/accounts'
import { getBooks } from '@/api/books'
import { getBanks, getAccountTemplates } from '@/api/reference'
import { exportTransactions, exportAccounts, exportCategories } from '@/api/exports'
import api from '@/api/index'
import type { BillImport, BillImportItem } from '@/api/imports'
import type { PaymentAccount, AccountBook } from '@/types'
import type { UploadFile } from 'element-plus'

interface UploadResult {
  id: number
  source: string
  parsed_count: number
  skipped_duplicate: number
  meta: {
    platform: string
    has_payment_method: boolean
    detected_methods: string[]
  }
  preview: Record<string, unknown>[]
}

interface BankItem { id: number; name: string; code: string; short_name: string }
interface TemplateItem { id: number; type_code: string; name: string; icon: string | null; group_name: string; is_credit: boolean; has_credit_limit: boolean; has_billing_day: boolean; has_due_day: boolean }

const loading = ref(false)
const uploading = ref(false)
const confirming = ref(false)
const savingAccount = ref(false)
const imports = ref<BillImport[]>([])
const items = ref<BillImportItem[]>([])
const books = ref<AccountBook[]>([])
const accounts = ref<PaymentAccount[]>([])
const banks = ref<BankItem[]>([])
const templates = ref<TemplateItem[]>([])
const showImportDialog = ref(false)
const showItemsDialog = ref(false)
const showExportDialog = ref(false)
const showAccountDialog = ref(false)
const selectedFile = ref<File | null>(null)
const uploadResult = ref<UploadResult | null>(null)
const step = ref(1)
const defaultAccountId = ref<number | null>(null)
const methodAccountMap = ref<Record<string, number | null>>({})
const currentCreateMethod = ref('')
const exportType = ref('transactions')
const exportFormat = ref('csv')

const sourceMap: Record<string, string> = { alipay: '支付宝', wechat: '微信', bank: '银行', auto: '自动' }
const statusMap: Record<string, string> = { pending: '待处理', parsed: '已解析', confirmed: '已导入', failed: '失败' }
const statusType: Record<string, string> = { pending: 'info', parsed: 'warning', confirmed: 'success', failed: 'danger' }
const actionMap: Record<string, string> = { pending: '待处理', imported: '已导入', skipped: '跳过', matched: '已匹配' }

const importForm = reactive({ book_id: 0, source: 'auto' })

const accountForm = reactive({
  type_code: '', name: '', bank_name: '', card_tail: '',
  credit_limit_yuan: 0, billing_day: null as number | null, due_day: null as number | null,
})

const currentTemplate = computed(() => templates.value.find((t) => t.type_code === accountForm.type_code))
const needBank = computed(() => ['bank_savings', 'bank_credit'].includes(accountForm.type_code))
const needCard = computed(() => ['bank_savings', 'bank_credit'].includes(accountForm.type_code))
const needCreditLimit = computed(() => currentTemplate.value?.has_credit_limit ?? false)
const needBillingDay = computed(() => currentTemplate.value?.has_billing_day ?? false)
const needDueDay = computed(() => currentTemplate.value?.has_due_day ?? false)

const templateGroups = computed(() => {
  const groups: Record<string, TemplateItem[]> = {}
  for (const t of templates.value) {
    if (!groups[t.group_name]) groups[t.group_name] = []
    groups[t.group_name].push(t)
  }
  return Object.entries(groups).map(([name, ts]) => ({ name, templates: ts }))
})

function formatMoney(val: number) { return `¥${(val / 100).toFixed(2)}` }

function onTypeChange() {
  const t = currentTemplate.value
  if (t) accountForm.name = t.name
}

function resetImport() {
  step.value = 1
  selectedFile.value = null
  uploadResult.value = null
  defaultAccountId.value = null
  methodAccountMap.value = {}
}

async function load() {
  loading.value = true
  try { imports.value = (await getImports()).data } finally { loading.value = false }
}

async function loadAccounts() {
  try { accounts.value = (await getAccounts()).data } catch {}
}

function handleFileChange(file: UploadFile) {
  selectedFile.value = file.raw || null
}

async function handleUpload() {
  if (!selectedFile.value || !importForm.book_id) { ElMessage.warning('请选择账本和文件'); return }
  uploading.value = true
  try {
    const formData = new FormData()
    formData.append('file', selectedFile.value)
    formData.append('book_id', String(importForm.book_id))
    formData.append('source', importForm.source)
    const res = await api.post('/imports/upload', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
    uploadResult.value = res.data
    step.value = 2

    // 初始化支付方式映射
    if (res.data.meta?.detected_methods) {
      for (const method of res.data.meta.detected_methods) {
        if (!(method in methodAccountMap.value)) {
          const matched = accounts.value.find((a) => a.name.includes(method) || method.includes(a.name))
          methodAccountMap.value[method] = matched?.id ?? null
        }
      }
    }
  } catch (err: unknown) {
    ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '上传失败')
  } finally { uploading.value = false }
}

async function handleConfirmImport() {
  if (!uploadResult.value) return
  confirming.value = true
  try {
    const mapping: Record<string, number> = {}
    for (const [k, v] of Object.entries(methodAccountMap.value)) {
      if (v) mapping[k] = v
    }
    const res = await api.post(`/imports/${uploadResult.value.id}/confirm`, {
      default_account_id: defaultAccountId.value || null,
      method_account_map: mapping,
    })
    ElMessage.success(res.data.message || '导入成功')
    showImportDialog.value = false
    resetImport()
    await load()
  } catch (err: unknown) {
    ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '导入失败')
  } finally { confirming.value = false }
}

function openCreateAccount(method: string) {
  currentCreateMethod.value = method
  const methodTypeMap: Record<string, string> = {
    '花呗': 'alipay_huabei', '余额宝': 'alipay_yuebao', '借呗': 'alipay_jiebei',
    '零钱': 'wechat_balance', '零钱通': 'wechat_lingqian',
  }
  accountForm.type_code = methodTypeMap[method] || 'bank_credit'
  accountForm.name = method
  accountForm.bank_name = ''
  accountForm.card_tail = ''
  accountForm.credit_limit_yuan = 0
  accountForm.billing_day = null
  accountForm.due_day = null
  showAccountDialog.value = true
}

async function handleCreateAccount() {
  if (!accountForm.name) { ElMessage.warning('请填写名称'); return }
  savingAccount.value = true
  try {
    const payload: Record<string, unknown> = {
      name: accountForm.name, type_code: accountForm.type_code,
    }
    if (needBank.value && accountForm.bank_name) payload.bank_name = accountForm.bank_name
    if (needCard.value && accountForm.card_tail) payload.card_tail = accountForm.card_tail
    if (needCreditLimit.value && accountForm.credit_limit_yuan) payload.credit_limit = Math.round(accountForm.credit_limit_yuan * 100)
    if (needBillingDay.value && accountForm.billing_day) payload.billing_day = accountForm.billing_day
    if (needDueDay.value && accountForm.due_day) payload.due_day = accountForm.due_day

    const res = await createAccount(payload as any)
    ElMessage.success('账户创建成功')
    showAccountDialog.value = false
    await loadAccounts()
    methodAccountMap.value[currentCreateMethod.value] = res.data.id
  } catch (err: unknown) {
    ElMessage.error((err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '创建失败')
  } finally { savingAccount.value = false }
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
  await Promise.all([
    load(),
    loadAccounts(),
    getBooks().then((r) => { books.value = r.data; if (books.value.length) importForm.book_id = books.value[0].id }),
    getBanks().then((r) => { banks.value = r.data }),
    getAccountTemplates().then((r) => { templates.value = r.data }),
  ])
})
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h3 { margin: 0; }
</style>
