<template>
  <el-popconfirm :title="title" @confirm="$emit('confirm')">
    <template #reference>
      <el-button link type="danger" size="small" :disabled="disabled">
        <slot>删除</slot>
      </el-button>
    </template>
  </el-popconfirm>
</template>

<script setup lang="ts">
withDefaults(defineProps<{
  title?: string
  disabled?: boolean
}>(), {
  title: '确定删除？',
  disabled: false,
})

defineEmits<{
  confirm: []
}>()
</script>
