<template>
  <div class="login-container">
    <el-card class="login-card">
      <template #header>
        <h2>家庭记账</h2>
      </template>

      <el-tabs v-model="activeTab">
        <el-tab-pane label="登录" name="login">
          <el-form :model="loginForm" @submit.prevent="handleLogin">
            <el-form-item label="手机号">
              <el-input v-model="loginForm.phone" placeholder="请输入手机号" />
            </el-form-item>
            <el-form-item label="密码">
              <el-input v-model="loginForm.password" type="password" placeholder="请输入密码" show-password />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" style="width: 100%" :loading="loading" @click="handleLogin">
                登录
              </el-button>
            </el-form-item>
          </el-form>
        </el-tab-pane>

        <el-tab-pane label="注册" name="register">
          <el-form :model="registerForm" @submit.prevent="handleRegister">
            <el-form-item label="昵称">
              <el-input v-model="registerForm.nickname" placeholder="请输入昵称" />
            </el-form-item>
            <el-form-item label="手机号">
              <el-input v-model="registerForm.phone" placeholder="请输入手机号" />
            </el-form-item>
            <el-form-item label="密码">
              <el-input v-model="registerForm.password" type="password" placeholder="请输入密码" show-password />
            </el-form-item>
            <el-form-item label="家庭名称">
              <el-input v-model="registerForm.family_name" placeholder="可选，如：我的家庭" />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" style="width: 100%" :loading="loading" @click="handleRegister">
                注册
              </el-button>
            </el-form-item>
          </el-form>
        </el-tab-pane>
      </el-tabs>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { ElMessage } from 'element-plus'

const router = useRouter()
const auth = useAuthStore()
const loading = ref(false)
const activeTab = ref('login')

const loginForm = reactive({ phone: '', password: '' })
const registerForm = reactive({ phone: '', password: '', nickname: '', family_name: '' })

async function handleLogin() {
  if (!loginForm.phone || !loginForm.password) {
    ElMessage.warning('请填写手机号和密码')
    return
  }
  loading.value = true
  try {
    await auth.login(loginForm)
    ElMessage.success('登录成功')
    router.push('/')
  } catch (err: unknown) {
    const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '登录失败'
    ElMessage.error(msg)
  } finally {
    loading.value = false
  }
}

async function handleRegister() {
  if (!registerForm.phone || !registerForm.password || !registerForm.nickname) {
    ElMessage.warning('请填写昵称、手机号和密码')
    return
  }
  loading.value = true
  try {
    await auth.register(registerForm)
    ElMessage.success('注册成功')
    router.push('/')
  } catch (err: unknown) {
    const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail || '注册失败'
    ElMessage.error(msg)
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background: #f5f5f5;
}
.login-card {
  width: 420px;
}
h2 {
  text-align: center;
  margin: 0;
}
</style>
