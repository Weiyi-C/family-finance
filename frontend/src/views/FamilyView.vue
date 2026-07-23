<template>
  <div>
    <div class="page-header">
      <h3>家庭管理</h3>
    </div>

    <!-- 家庭信息 -->
    <el-card style="margin-bottom: 16px;">
      <template #header>
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <span>家庭信息</span>
          <el-button size="small" @click="editFamilyName" v-if="isOwnerOrAdmin">修改名称</el-button>
        </div>
      </template>
      <el-descriptions :column="2" border>
        <el-descriptions-item label="家庭名称">{{ family.name }}</el-descriptions-item>
        <el-descriptions-item label="家庭ID">{{ family.id }}</el-descriptions-item>
        <el-descriptions-item label="创建时间">{{ family.created_at ? new Date(family.created_at).toLocaleString('zh-CN') : '-' }}</el-descriptions-item>
        <el-descriptions-item label="成员数">{{ members.length }}</el-descriptions-item>
      </el-descriptions>
    </el-card>

    <!-- 成员管理 -->
    <el-card>
      <template #header>
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <span>家庭成员</span>
          <el-button type="primary" size="small" @click="showAddDialog = true" v-if="isOwnerOrAdmin">
            <el-icon><Plus /></el-icon> 邀请成员
          </el-button>
        </div>
      </template>
      <el-table :data="members" stripe>
        <el-table-column label="成员" min-width="150">
          <template #default="{ row }">
            <div style="display: flex; align-items: center; gap: 8px;">
              <el-avatar :size="32" :icon="UserFilled" />
              <div>
                <div style="font-weight: 500;">{{ row.nickname }}</div>
                <div style="font-size: 12px; color: #909399;">{{ row.phone || '-' }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="角色" width="150">
          <template #default="{ row }">
            <el-tag :type="roleTagType(row.role)" size="small">{{ roleMap[row.role] || row.role }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" v-if="isOwner">
          <template #default="{ row }">
            <el-select
              v-if="row.id !== currentUserId"
              :model-value="row.role"
              size="small"
              style="width: 100px;"
              @change="(val: string) => handleRoleChange(row.id, val)"
            >
              <el-option label="管理员" value="admin" />
              <el-option label="普通成员" value="member" />
            </el-select>
            <el-popconfirm
              v-if="row.id !== currentUserId"
              title="确定移除该成员？"
              @confirm="handleRemove(row.id)"
            >
              <template #reference>
                <el-button link type="danger" size="small" style="margin-left: 8px;">移除</el-button>
              </template>
            </el-popconfirm>
            <el-tag v-if="row.id === currentUserId" type="info" size="small">当前用户</el-tag>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 邀请成员对话框 -->
    <el-dialog v-model="showAddDialog" title="邀请成员" width="400px" destroy-on-close>
      <el-form :model="addForm" label-width="80px">
        <el-form-item label="手机号">
          <el-input v-model="addForm.phone" placeholder="输入已注册用户的手机号" />
        </el-form-item>
        <el-form-item label="角色">
          <el-select v-model="addForm.role" style="width: 100%;">
            <el-option label="管理员" value="admin" />
            <el-option label="普通成员" value="member" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showAddDialog = false">取消</el-button>
        <el-button type="primary" :loading="adding" @click="handleAdd">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { Plus, UserFilled } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useAuthStore } from '@/stores/auth'
import {
  getCurrentFamily, updateFamily, getMembers, addMember, updateMember, removeMember,
} from '@/api/families'
import type { FamilyMember, FamilyInfo } from '@/api/families'

const auth = useAuthStore()
const currentUserId = computed(() => auth.user?.id || 0)
const currentUserRole = computed(() => auth.user?.role || 'member')
const isOwner = computed(() => currentUserRole.value === 'owner')
const isOwnerOrAdmin = computed(() => ['owner', 'admin'].includes(currentUserRole.value))

const family = reactive<FamilyInfo>({ id: 0, name: '', created_by: 0, created_at: '' })
const members = ref<FamilyMember[]>([])
const showAddDialog = ref(false)
const adding = ref(false)
const addForm = reactive({ phone: '', role: 'member' })

const roleMap: Record<string, string> = { owner: '拥有者', admin: '管理员', member: '普通成员' }

function roleTagType(role: string) {
  if (role === 'owner') return 'danger'
  if (role === 'admin') return 'warning'
  return 'info'
}

async function load() {
  try {
    const [familyRes, membersRes] = await Promise.all([
      getCurrentFamily(),
      getMembers(),
    ])
    Object.assign(family, familyRes.data)
    members.value = membersRes.data
  } catch {
    ElMessage.error('加载家庭信息失败')
  }
}

async function editFamilyName() {
  try {
    const { value } = await ElMessageBox.prompt('请输入新的家庭名称', '修改名称', {
      inputValue: family.name,
      inputPattern: /.+/,
      inputErrorMessage: '名称不能为空',
    })
    await updateFamily({ name: value })
    family.name = value
    ElMessage.success('修改成功')
  } catch { /* cancelled */ }
}

async function handleAdd() {
  if (!addForm.phone) { ElMessage.warning('请输入手机号'); return }
  adding.value = true
  try {
    await addMember({ phone: addForm.phone, role: addForm.role })
    ElMessage.success('添加成功')
    showAddDialog.value = false
    addForm.phone = ''
    addForm.role = 'member'
    await load()
  } catch (err: any) {
    ElMessage.error(err?.response?.data?.detail || '添加失败')
  } finally {
    adding.value = false
  }
}

async function handleRoleChange(memberId: number, role: string) {
  try {
    await updateMember(memberId, { role })
    ElMessage.success('角色已更新')
    await load()
  } catch {
    ElMessage.error('更新失败')
  }
}

async function handleRemove(memberId: number) {
  try {
    await removeMember(memberId)
    ElMessage.success('已移除')
    await load()
  } catch {
    ElMessage.error('移除失败')
  }
}

onMounted(load)
</script>

<style scoped>
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}
.page-header h3 { margin: 0; }
</style>
