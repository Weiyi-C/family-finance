<template>
  <el-tag :type="tagType" :size="size">{{ label }}</el-tag>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(defineProps<{
  value: string
  map: Record<string, string>
  typeMap?: Record<string, string>
  size?: 'small' | 'default' | 'large'
}>(), {
  typeMap: () => ({
    pending: 'warning',
    paid: 'success',
    partial: 'info',
    overdue: 'danger',
    active: 'success',
    inactive: 'info',
    confirmed: 'success',
    imported: 'success',
    skipped: 'warning',
  }),
  size: 'small',
})

const label = computed(() => props.map[props.value] || props.value)
const tagType = computed(() => (props.typeMap?.[props.value] || '') as any)
</script>
