<template>
  <el-container class="main-layout">
    <el-aside :width="isCollapsed ? '64px' : '220px'" class="sidebar">
      <div class="logo" @click="router.push('/')">
        <el-icon :size="24"><Wallet /></el-icon>
        <span v-if="!isCollapsed" class="logo-text">家庭记账</span>
      </div>
      <el-menu
        :default-active="activeMenu"
        :collapse="isCollapsed"
        router
        class="sidebar-menu"
      >
        <el-menu-item index="/">
          <el-icon><HomeFilled /></el-icon>
          <template #title>首页</template>
        </el-menu-item>
        <el-menu-item index="/transactions">
          <el-icon><List /></el-icon>
          <template #title>记账</template>
        </el-menu-item>
        <el-menu-item index="/accounts">
          <el-icon><CreditCard /></el-icon>
          <template #title>账户</template>
        </el-menu-item>
        <el-menu-item index="/categories">
          <el-icon><Grid /></el-icon>
          <template #title>分类</template>
        </el-menu-item>
        <el-menu-item index="/budgets">
          <el-icon><Coin /></el-icon>
          <template #title>预算</template>
        </el-menu-item>
        <el-menu-item index="/stats">
          <el-icon><DataAnalysis /></el-icon>
          <template #title>统计</template>
        </el-menu-item>
        <el-menu-item index="/debts">
          <el-icon><Money /></el-icon>
          <template #title>借贷</template>
        </el-menu-item>
        <el-menu-item index="/savings">
          <el-icon><Aim /></el-icon>
          <template #title>储蓄</template>
        </el-menu-item>
        <el-menu-item index="/credit-bills">
          <el-icon><CreditCard /></el-icon>
          <template #title>信用卡</template>
        </el-menu-item>
        <el-menu-item index="/recurring">
          <el-icon><Clock /></el-icon>
          <template #title>周期交易</template>
        </el-menu-item>
        <el-menu-item index="/reimbursements">
          <el-icon><Document /></el-icon>
          <template #title>报销</template>
        </el-menu-item>
        <el-menu-item index="/import">
          <el-icon><Upload /></el-icon>
          <template #title>导入/导出</template>
        </el-menu-item>
        <el-menu-item index="/notifications">
          <el-icon><Bell /></el-icon>
          <template #title>通知</template>
        </el-menu-item>
        <el-menu-item index="/aliases">
          <el-icon><Connection /></el-icon>
          <template #title>商户别名</template>
        </el-menu-item>
        <el-menu-item index="/rules">
          <el-icon><SetUp /></el-icon>
          <template #title>规则引擎</template>
        </el-menu-item>
        <el-menu-item index="/backup">
          <el-icon><FolderOpened /></el-icon>
          <template #title>备份</template>
        </el-menu-item>
        <el-menu-item index="/sync">
          <el-icon><Refresh /></el-icon>
          <template #title>同步</template>
        </el-menu-item>
        <el-menu-item index="/books">
          <el-icon><Notebook /></el-icon>
          <template #title>账本</template>
        </el-menu-item>
        <el-menu-item index="/tags">
          <el-icon><PriceTag /></el-icon>
          <template #title>标签</template>
        </el-menu-item>
        <el-menu-item index="/settings">
          <el-icon><Setting /></el-icon>
          <template #title>设置</template>
        </el-menu-item>
      </el-menu>
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
          <el-dropdown @command="handleCommand">
            <span class="user-info">
              <el-avatar :size="32" :icon="UserFilled" />
              <span class="user-name">{{ auth.user?.nickname || '用户' }}</span>
              <el-icon><ArrowDown /></el-icon>
            </span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="settings">设置</el-dropdown-item>
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
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import {
  HomeFilled, List, CreditCard, Grid, Coin, DataAnalysis, Money, Aim,
  Clock, Document, Notebook, PriceTag, Setting, Fold, Expand,
  ArrowDown, UserFilled, Wallet, Upload, Bell, Connection, SetUp, FolderOpened, Refresh,
} from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const isCollapsed = ref(false)

const activeMenu = computed(() => route.path)

const titleMap: Record<string, string> = {
  '/': '首页',
  '/transactions': '记账',
  '/accounts': '账户管理',
  '/categories': '分类管理',
  '/budgets': '预算管理',
  '/stats': '统计分析',
  '/debts': '借贷管理',
  '/savings': '储蓄目标',
  '/credit-bills': '信用卡账单',
  '/recurring': '周期交易',
  '/reimbursements': '报销管理',
  '/import': '导入/导出',
  '/notifications': '通知',
  '/aliases': '商户别名',
  '/rules': '规则引擎',
  '/backup': '备份管理',
  '/sync': '数据同步',
  '/books': '账本管理',
  '/tags': '标签管理',
  '/settings': '设置',
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
</script>

<style scoped>
.main-layout {
  height: 100vh;
}
.sidebar {
  background: #304156;
  display: flex;
  flex-direction: column;
  transition: width 0.3s;
  overflow: hidden;
}
.logo {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 16px;
  color: #fff;
  cursor: pointer;
}
.logo-text {
  font-size: 18px;
  font-weight: 600;
  white-space: nowrap;
}
.sidebar-menu {
  flex: 1;
  border-right: none;
  background: #304156;
}
.sidebar-menu .el-menu-item {
  color: #bfcbd9;
}
.sidebar-menu .el-menu-item:hover,
.sidebar-menu .el-menu-item.is-active {
  background: #263445;
  color: #409eff;
}
.collapse-btn {
  padding: 12px;
  text-align: center;
  color: #bfcbd9;
  cursor: pointer;
  border-top: 1px solid #3a4a5b;
}
.collapse-btn:hover {
  color: #409eff;
}
.top-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid #e6e6e6;
  background: #fff;
  padding: 0 20px;
  height: 56px;
}
.top-left h3 {
  margin: 0;
  font-size: 16px;
  color: #333;
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
.user-name {
  font-size: 14px;
}
.content-area {
  background: #f5f7fa;
  padding: 20px;
}
</style>
