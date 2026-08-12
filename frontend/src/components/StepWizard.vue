<template>
  <div class="step-wizard">
    <el-steps :active="currentStep" finish-status="success" class="wizard-steps">
      <el-step
        v-for="(step, index) in steps"
        :key="index"
        :title="step.title"
        :description="step.description"
      />
    </el-steps>

    <div class="wizard-content">
      <slot :name="`step-${currentStep}`" />
    </div>

    <div class="wizard-footer">
      <slot name="footer">
        <el-button v-if="currentStep > 0" @click="prevStep">上一步</el-button>
        <div class="wizard-footer-right">
          <el-button @click="$emit('cancel')">取消</el-button>
          <el-button
            v-if="currentStep < steps.length - 1"
            type="primary"
            :disabled="!canNext"
            @click="nextStep"
          >
            下一步
          </el-button>
          <el-button
            v-else
            type="success"
            :loading="loading"
            :disabled="!canNext"
            @click="$emit('confirm')"
          >
            {{ confirmText }}
          </el-button>
        </div>
      </slot>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'

interface StepConfig {
  title: string
  description?: string
}

const props = withDefaults(defineProps<{
  steps: StepConfig[]
  initialStep?: number
  canNext?: boolean
  loading?: boolean
  confirmText?: string
}>(), {
  initialStep: 0,
  canNext: true,
  loading: false,
  confirmText: '确认',
})

const emit = defineEmits<{
  cancel: []
  confirm: []
  'step-change': [step: number]
}>()

const currentStep = ref(props.initialStep)

watch(() => props.initialStep, (val) => {
  currentStep.value = val
})

function nextStep() {
  if (currentStep.value < props.steps.length - 1 && props.canNext) {
    currentStep.value++
    emit('step-change', currentStep.value)
  }
}

function prevStep() {
  if (currentStep.value > 0) {
    currentStep.value--
    emit('step-change', currentStep.value)
  }
}

function goToStep(step: number) {
  if (step >= 0 && step < props.steps.length) {
    currentStep.value = step
    emit('step-change', currentStep.value)
  }
}

defineExpose({ nextStep, prevStep, goToStep, currentStep })
</script>

<style scoped>
.step-wizard {
  display: flex;
  flex-direction: column;
  gap: 24px;
}
.wizard-steps {
  padding: 0 40px;
}
.wizard-content {
  min-height: 200px;
}
.wizard-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 16px;
  border-top: 1px solid var(--color-border);
}
.wizard-footer-right {
  display: flex;
  gap: 8px;
}
</style>
