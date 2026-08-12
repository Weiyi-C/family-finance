export function formatMoney(val: number | null | undefined): string {
  if (val === null || val === undefined) return '¥0.00'
  return `¥${(val / 100).toFixed(2)}`
}

export function formatMoneyShort(val: number | null | undefined): string {
  if (val === null || val === undefined) return '¥0'
  const yuan = val / 100
  if (yuan >= 10000) return `¥${(yuan / 10000).toFixed(1)}万`
  if (yuan >= 1000) return `¥${(yuan / 1000).toFixed(1)}千`
  return `¥${yuan.toFixed(2)}`
}
