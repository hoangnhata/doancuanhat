const fmt = new Intl.NumberFormat('vi-VN', {
  notation: 'compact',
  maximumFractionDigits: 2,
});

export function formatMoney(n: number): string {
  return `${fmt.format(n)}₫`;
}

export function formatMoneyFull(n: number): string {
  return `${new Intl.NumberFormat('vi-VN').format(Math.round(n))}₫`;
}
