/** ECharts 主题色工具 - 从 CSS 变量读取颜色 */

export function getChartColors() {
  const style = getComputedStyle(document.documentElement)
  return {
    primary: style.getPropertyValue('--color-primary').trim() || '#409eff',
    primaryLight: style.getPropertyValue('--color-primary-light').trim() || '#66b1ff',
    expense: style.getPropertyValue('--color-expense').trim() || '#f56c6c',
    income: style.getPropertyValue('--color-income').trim() || '#67c23a',
    warning: style.getPropertyValue('--color-warning').trim() || '#e6a23c',
    info: style.getPropertyValue('--color-info').trim() || '#909399',
    textPrimary: style.getPropertyValue('--color-text-primary').trim() || '#303133',
    textRegular: style.getPropertyValue('--color-text-regular').trim() || '#606266',
    textSecondary: style.getPropertyValue('--color-text-secondary').trim() || '#909399',
    border: style.getPropertyValue('--color-border').trim() || '#dcdfe6',
    borderLight: style.getPropertyValue('--color-border-light').trim() || '#e4e7ed',
    bgPage: style.getPropertyValue('--color-bg-page').trim() || '#f5f7fa',
    bgCard: style.getPropertyValue('--color-bg-card').trim() || '#ffffff',
  }
}

/** 饼图/柱状图调色板 */
export function getChartPalette(): string[] {
  const c = getChartColors()
  return [
    c.primary,
    c.expense,
    c.income,
    c.warning,
    '#8b5cf6',
    '#14b8a6',
    '#ec4899',
    '#6366f1',
    '#f97316',
    '#06b6d4',
    '#84cc16',
    '#a855f7',
  ]
}

/** ECharts 通用主题配置 */
export function getChartTheme() {
  const c = getChartColors()
  return {
    backgroundColor: 'transparent',
    textStyle: { color: c.textRegular },
    title: { textStyle: { color: c.textPrimary } },
    legend: { textStyle: { color: c.textSecondary } },
    tooltip: {
      backgroundColor: c.bgCard,
      borderColor: c.borderLight,
      textStyle: { color: c.textPrimary },
    },
    categoryAxis: {
      axisLine: { lineStyle: { color: c.border } },
      axisTick: { lineStyle: { color: c.border } },
      axisLabel: { color: c.textSecondary },
      splitLine: { lineStyle: { color: c.borderLight } },
    },
    valueAxis: {
      axisLine: { lineStyle: { color: c.border } },
      axisTick: { lineStyle: { color: c.border } },
      axisLabel: { color: c.textSecondary },
      splitLine: { lineStyle: { color: c.borderLight } },
    },
  }
}
