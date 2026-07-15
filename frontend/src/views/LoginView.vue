<template>
  <div class="login-container">
    <el-card class="login-card">
      <template #header>
        <h2>家庭记账</h2>
      </template>
      <el-form>
        <el-form-item label="手机号">
          <el-input v-model="phone" placeholder="请输入手机号" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="password" type="password" placeholder="请输入密码" show-password />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" style="width: 100%">登录</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const phone = ref('')
const password = ref('')
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
  width: 400px;
}
h2 {
  text-align: center;
  margin: 0;
}
</style>
