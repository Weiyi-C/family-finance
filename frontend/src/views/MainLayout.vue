<template>
  <el-container class="main-layout">
    <el-aside :width="isCollapsed ? '64px' : '220px'" class="sidebar">
      <div class="logo" @click="router.push('/')">
        <el-icon :size="24"><Wallet /></el-icon>
        <span v-if="!isCollapsed" class="logo-text">家庭记账</span>
      </div>
      <el-scrollbar class="menu-scrollbar">
        <el-menu
          :default-active="activeMenu"
          :default-openeds="openedMenus"
          :collapse="isCollapsed"
          router
          class="sidebar-menu"
          background-color="#2b3a4a"
          text-color="#ffffff"
          active-text-color="#409eff"
        >
          <!-- 首页 -->
          <el-menu-item index="/">
            <el-icon><HomeFilled /></el-icon>
            <template #title>首页</template>
          </el-menu-item>

          <!-- 记账核心 -->
          <el-sub-menu index="accounting">
            <template #title>
              <el-icon><List /></el-icon>
              <span>记账</span>
            </template>
            <el-menu-item index="/transactions">交易记录</el-menu-item>
            <el-menu-item index="/recurring">周期交易</el-menu-item>
            <el-menu-item index="/import">导入/导出</el-menu-item>
          </el-sub-menu>

          <!-- 账户管理 -->
          <el-sub-menu index="assets">
            <template #title>
              <el-icon><CreditCard /></el-icon>
              <span>账户</span>
            </template>
            <el-menu-item index="/accounts">资金账户</el-menu-item>
            <el-menu-item index="/credit-bills">信用卡账单</el-menu-item>
            <el-menu-item index="/debts">借贷管理</el-menu-item>
            <el-menu-item index="/savings">储蓄目标</el-menu-item>
          </el-sub-menu>

          <!-- 预算与统计 -->
          <el-sub-menu index="analysis">
            <template #title>
              <el-icon><DataAnalysis /></el-icon>
              <span>分析</span>
            </template>
            <el-menu-item index="/budgets">预算管理</el-menu-item>
            <el-menu-item index="/stats">统计报表</el-menu-item>
          </el-sub-menu>

          <!-- 报销 -->
          <el-menu-item index="/reimbursements">
            <el-icon><Document /></el-icon>
            <template #title>报销</template>
          </el-menu-item>

          <!-- 基础设置 -->
          <el-sub-menu index="settings">
            <template #title>
              <el-icon><Setting /></el-icon>
              <span>设置</span>
            </template>
            <el-menu-item index="/books">账本管理</el-menu-item>
            <el-menu-item index="/categories">分类管理</el-menu-item>
            <el-menu-item index="/tags">标签管理</el-menu-item>
            <el-menu-item index="/aliases">商户别名</el-menu-item>
            <el-menu-item index="/rules">规则引擎</el-menu-item>
          </el-sub-menu>

          <!-- 系统 -->
          <el-sub-menu index="system">
            <template #title>
              <el-icon><SetUp /></el-icon>
              <span>系统</span>
            </template>
            <el-menu-item index="/settings">个人设置</el-menu-item>
            <el-menu-item index="/notifications">通知</el-menu-item>
            <el-menu-item index="/backup">备份恢复</el-menu-item>
            <el-menu-item index="/sync">数据同步</el-menu-item>
          </el-sub-menu>
        </el-menu>
      </el-scrollbar>
      <div class="collapse-btn" @click="isCollapsed = !isCollapsed">
        <el-icon>
          <Fold v-if="!isCollapsed" />
          <Expand v-else />
        </el-icon>
      </div>
    </el-aside>

    <el-container>
      <el-header class="top-bar">
        <div class="top-left">
          <h3>{{ routeTitle }}</h3>
        </div>
        <div class="top-right">
          <el-badge :value="unreadCount" :hidden="unreadCount === 0" class="notification-badge">
            <el-button :icon="Bell" circle size="small" @click="router.push('/notifications')" />
          </el-badge>
          <el-dropdown @command="handleCommand" style="margin-left: 16px;">
            <span class="user-info">
              <el-avatar :size="32" :icon="UserFilled" />
              <span class="user-name">{{ auth.user?.nickname || '用户' }}</span>
              <el-icon><ArrowDown /></el-icon>
            </span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="settings">个人设置</el-dropdown-item>
                <el-dropdown-item command="logout" divided>退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>
      <el-main class="content-area">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { getUnreadCount } from '@/api/notifications'
import {
  HomeFilled, List, CreditCard, DataAnalysis, Document, Setting, SetUp,
  Fold, Expand, ArrowDown, UserFilled, Wallet, Bell,
} from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const isCollapsed = ref(false)
const unreadCount = ref(0)

const openedMenus = ref(['accounting', 'assets', 'analysis', 'settings', 'system'])

const activeMenu = computed(() => route.path)

const titleMap: Record<string, string> = {
  '/': '首页',
  '/transactions': '交易记录',
  '/accounts': '资金账户',
  '/categories': '分类管理',
  '/budgets': '预算管理',
  '/stats': '统计报表',
  '/debts': '借贷管理',
  '/savings': '储蓄目标',
  '/credit-bills': '信用卡账单',
  '/recurring': '周期交易',
  '/reimbursements': '报销管理',
  '/import': '导入/导出',
  '/notifications': '通知',
  '/aliases': '商户别名',
  '/rules': '规则引擎',
  '/backup': '备份恢复',
  '/sync': '数据同步',
  '/books': '账本管理',
  '/tags': '标签管理',
  '/settings': '个人设置',
}

const routeTitle = computed(() => titleMap[route.path] || '家庭记账')

async function handleCommand(cmd: string) {
  if (cmd === 'logout') {
    await auth.logout()
    router.push('/login')
  } else if (cmd === 'settings') {
    router.push('/settings')
  }
}

async function loadUnreadCount() {
  try {
    const res = await getUnreadCount()
    unreadCount.value = res.data.count
  } catch { /* ignore */ }
}

onMounted(loadUnreadCount)
</script>

<style scoped>
.main-layout {
  height: 100vh;
}
.sidebar {
  background: #2b3a4a;
  display: flex;
  flex-direction: column;
  transition: width 0.3s;
  overflow: hidden;
}
.logo {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 18px 16px;
  color: #fff;
  cursor: pointer;
  flex-shrink: 0;
  background: #1f2d3d;
  border-bottom: 1px solid #3a4a5a;
}
.logo-text {
  font-size: 18px;
  font-weight: 600;
  white-space: nowrap;
}
.menu-scrollbar {
  flex: 1;
  overflow: hidden;
}
.sidebar-menu {
  border-right: none;
}
.sidebar-menu .el-menu-item {
  color: #d4d7de !important;
  height: 44px;
  line-height: 44px;
  padding-left: 56px !important;
}
.sidebar-menu .el-menu-item:hover {
  background: #354555 !important;
  color: #fff !important;
}
.sidebar-menu .el-menu-item.is-active {
  background: #409eff !important;
  color: #fff !important;
}
.collapse-btn {
  padding: 14px;
  text-align: center;
  color: #909399;
  cursor: pointer;
  border-top: 1px solid #3a4a5a;
  flex-shrink: 0;
}
.collapse-btn:hover {
  color: #fff;
  background: #354555;
}
.top-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid #dcdfe6;
  background: #fff;
  padding: 0 24px;
  height: 56px;
}
.top-left h3 {
  margin: 0;
  font-size: 16px;
  color: #303133;
  font-weight: 600;
}
.top-right {
  display: flex;
  align-items: center;
}
.user-info {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  color: #606266;
}
.user-info:hover {
  color: #409eff;
}
.user-name {
  font-size: 14px;
}
.notification-badge {
  margin-right: 8px;
}
.content-area {
  background: #f5f7fa;
  padding: 20px;
  overflow-y: auto;
}
</style>
