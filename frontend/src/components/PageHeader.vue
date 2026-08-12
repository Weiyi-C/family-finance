<template>
  <div class="page-header">
    <h3>{{ title }}</h3>
    <div class="page-header-actions">
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  title: string
}>()
</script>

<style scoped>
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}
.page-header h3 {
  margin: 0;
}
.page-header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}
</style>
