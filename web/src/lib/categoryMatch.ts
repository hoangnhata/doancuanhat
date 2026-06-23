import type { AICategorizeResponse, Category } from '@/types/models';

/** Khớp danh mục từ kết quả AI (id hoặc tên gần đúng). */
export function findCategoryFromAi(
  cats: Category[],
  result: AICategorizeResponse,
): Category | undefined {
  if (result.categoryId != null) {
    const byId = cats.find((c) => c.id === result.categoryId);
    if (byId) return byId;
  }
  const raw = (result.categoryName ?? result.suggestedCategoryName ?? '')
    .trim()
    .toLowerCase();
  if (!raw) return undefined;
  return cats.find(
    (c) =>
      c.name.toLowerCase() === raw ||
      c.name.toLowerCase().includes(raw) ||
      raw.includes(c.name.toLowerCase()),
  );
}

/** Phân loại nhanh từ tên mục tiêu tiết kiệm (trước / song song với AI). */
export function guessCategoryFromGoalName(
  cats: Category[],
  goalName: string,
): Category | undefined {
  const t = goalName.toLowerCase().normalize('NFC');
  const rules: [RegExp, string][] = [
    [/\b(laptop|lap\s*top|mua\s+lap\b|macbook|ipad|iphone|điện thoại|dien thoai|máy tính|may tinh)\b/, 'Mua sắm'],
    [/\b(mua|sắm|sam|shop|shopee|lazada|tiki|quần áo|giày|son|mỹ phẩm)\b/, 'Mua sắm'],
    [/\b(du lịch|du lich|khách sạn|tour|vé máy bay|resort)\b/, 'Du lịch'],
    [/\b(xe|ô tô|oto|xăng|grab|uber|taxi|di chuyển)\b/, 'Di chuyển'],
    [/\b(ăn|uống|cơm|phở|cafe|trà sữa|quán)\b/, 'Ăn uống'],
    [/\b(học|sách|khóa học|giáo dục|học phí)\b/, 'Giáo dục'],
    [/\b(phim|game|giải trí|karaoke|netflix)\b/, 'Giái trí'],
    [/\b(thuê nhà|tiền nhà|chung cư|nội thất)\b/, 'Nhà ở'],
    [/\b(điện|nước|internet|wifi|hóa đơn)\b/, 'Hóa đơn'],
    [/\b(khám|thuốc|bệnh|viện|gym|sức khỏe)\b/, 'Sức khỏe'],
  ];

  for (const [re, label] of rules) {
    if (!re.test(t)) continue;
    const found = cats.find(
      (c) =>
        c.name.toLowerCase() === label.toLowerCase() ||
        c.name.toLowerCase().includes(label.toLowerCase()) ||
        label.toLowerCase().includes(c.name.toLowerCase()),
    );
    if (found) return found;
  }
  return undefined;
}
