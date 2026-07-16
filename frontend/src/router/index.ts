import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/LoginView.vue'),
      meta: { guest: true },
    },
    {
      path: '/',
      component: () => import('@/views/MainLayout.vue'),
      children: [
        { path: '', name: 'home', component: () => import('@/views/HomeView.vue') },
        { path: 'transactions', name: 'transactions', component: () => import('@/views/TransactionView.vue') },
        { path: 'accounts', name: 'accounts', component: () => import('@/views/AccountView.vue') },
        { path: 'categories', name: 'categories', component: () => import('@/views/CategoryView.vue') },
        { path: 'budgets', name: 'budgets', component: () => import('@/views/BudgetView.vue') },
        { path: 'stats', name: 'stats', component: () => import('@/views/StatsView.vue') },
        { path: 'books', name: 'books', component: () => import('@/views/BookView.vue') },
        { path: 'tags', name: 'tags', component: () => import('@/views/TagView.vue') },
        { path: 'debts', name: 'debts', component: () => import('@/views/DebtView.vue') },
        { path: 'recurring', name: 'recurring', component: () => import('@/views/RecurringView.vue') },
        { path: 'reimbursements', name: 'reimbursements', component: () => import('@/views/ReimbursementView.vue') },
        { path: 'savings', name: 'savings', component: () => import('@/views/SavingsView.vue') },
        { path: 'settings', name: 'settings', component: () => import('@/views/SettingsView.vue') },
      ],
    },
  ],
})

router.beforeEach(async (to, _from, next) => {
  const auth = useAuthStore()

  if (!auth.isLoggedIn && localStorage.getItem('access_token')) {
    await auth.init()
  }

  if (to.meta.guest) {
    if (auth.isLoggedIn) {
      next({ name: 'home' })
    } else {
      next()
    }
  } else {
    if (auth.isLoggedIn) {
      next()
    } else {
      next({ name: 'login' })
    }
  }
})

export default router
