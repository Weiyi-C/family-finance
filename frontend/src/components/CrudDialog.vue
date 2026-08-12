<template>
  <el-dialog
    :model-value="modelValue"
    :title="isEdit ? `编辑${entityName}` : `新建${entityName}`"
    :width="width"
    destroy-on-close
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <slot />
    <template #footer>
      <el-button @click="$emit('update:modelValue', false)">取消</el-button>
      <el-button type="primary" :loading="saving" @click="$emit('save')">保存</el-button>
    </template>
  </el-dialog>
</template>

<script setup lang="ts">
withDefaults(defineProps<{
  modelValue: boolean
  entityName: string
  isEdit?: boolean
  saving?: boolean
  width?: string
}>(), {
  isEdit: false,
  saving: false,
  width: '400px',
})

defineEmits<{
  'update:modelValue': [value: boolean]
  save: []
}>()
</script>
