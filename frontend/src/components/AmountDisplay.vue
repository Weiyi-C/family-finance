<template>
  <span class="amount-display" :class="typeClass">
    {{ formatted }}
  </span>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { formatMoney } from '@/utils/format'

const props = defineProps<{
  value: number | null | undefined
  type?: 'expense' | 'income' | 'transfer' | string
}>()

const formatted = computed(() => {
  if (props.type === 'transfer') return formatMoney(props.value)
  return formatMoney(props.value)
})

const typeClass = computed(() => {
  if (props.type === 'income') return 'amount-income'
  if (props.type === 'expense') return 'amount-expense'
  if (props.type === 'transfer') return 'amount-transfer'
  return ''
})
</script>

<style scoped>
.amount-display {
  font-weight: 600;
}
.amount-income {
  color: var(--color-success, #67c23a);
}
.amount-expense {
  color: var(--color-danger, #f56c6c);
}
.amount-transfer {
  color: var(--color-info, #909399);
}
</style>
