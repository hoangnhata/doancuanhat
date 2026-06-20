import type { SvgIconComponent } from '@mui/icons-material';
import {
  AccountBalanceWalletOutlined,
  CardGiftcardOutlined,
  CategoryOutlined,
  DirectionsCarOutlined,
  EmojiEventsOutlined,
  FamilyRestroomOutlined,
  HomeOutlined,
  LaptopMacOutlined,
  LocalHospitalOutlined,
  LuggageOutlined,
  MenuBookOutlined,
  MoreHorizOutlined,
  MovieOutlined,
  PaymentsOutlined,
  PetsOutlined,
  PushPinOutlined,
  ReceiptLongOutlined,
  RestaurantOutlined,
  ShoppingBagOutlined,
  StorefrontOutlined,
  TrendingUpOutlined,
  VolunteerActivismOutlined,
} from '@mui/icons-material';
import { Box } from '@mui/material';
import { palette } from '@/theme';

const NAME_ICON_MAP: Record<string, SvgIconComponent> = {
  'ăn uống': RestaurantOutlined,
  'di chuyển': DirectionsCarOutlined,
  'nhà ở': HomeOutlined,
  'hóa đơn': ReceiptLongOutlined,
  'mua sắm': ShoppingBagOutlined,
  'giải trí': MovieOutlined,
  'du lịch': LuggageOutlined,
  'giáo dục': MenuBookOutlined,
  'sức khỏe': LocalHospitalOutlined,
  'gia đình': FamilyRestroomOutlined,
  'thú cưng': PetsOutlined,
  'quà tặng': CardGiftcardOutlined,
  'từ thiện': VolunteerActivismOutlined,
  khác: PushPinOutlined,
  lương: AccountBalanceWalletOutlined,
  thưởng: EmojiEventsOutlined,
  freelance: LaptopMacOutlined,
  'đầu tư': TrendingUpOutlined,
  'bán hàng': StorefrontOutlined,
  'thu nhập khác': MoreHorizOutlined,
};

const EMOJI_ICON_MAP: Record<string, SvgIconComponent> = {
  '🍔': RestaurantOutlined,
  '🚗': DirectionsCarOutlined,
  '🏠': HomeOutlined,
  '📄': ReceiptLongOutlined,
  '🛍️': ShoppingBagOutlined,
  '🎬': MovieOutlined,
  '🧳': LuggageOutlined,
  '📚': MenuBookOutlined,
  '💊': LocalHospitalOutlined,
  '👨‍👩‍👧‍👦': FamilyRestroomOutlined,
  '🐾': PetsOutlined,
  '🎁': CardGiftcardOutlined,
  '🤝': VolunteerActivismOutlined,
  '📌': PushPinOutlined,
  '💰': AccountBalanceWalletOutlined,
  '💻': LaptopMacOutlined,
  '📈': TrendingUpOutlined,
  '🛒': StorefrontOutlined,
};

const CATEGORY_COLORS = [
  '#0288D1',
  '#7B1FA2',
  '#00897B',
  '#F57C00',
  '#C2185B',
  '#3949AB',
  '#689F38',
  '#D84315',
];

export function resolveCategoryIcon(name: string, icon?: string | null): SvgIconComponent {
  if (icon && EMOJI_ICON_MAP[icon]) return EMOJI_ICON_MAP[icon];
  const key = name.trim().toLowerCase();
  if (NAME_ICON_MAP[key]) return NAME_ICON_MAP[key];
  for (const [part, Ico] of Object.entries(NAME_ICON_MAP)) {
    if (key.includes(part)) return Ico;
  }
  return CategoryOutlined;
}

export function categoryColor(index: number): string {
  return CATEGORY_COLORS[index % CATEGORY_COLORS.length];
}

type BadgeProps = {
  name: string;
  icon?: string | null;
  colorIndex?: number;
  size?: number;
};

export function CategoryIconBadge({ name, icon, colorIndex = 0, size = 36 }: BadgeProps) {
  const Icon = resolveCategoryIcon(name, icon);
  const color = categoryColor(colorIndex);
  const iconSize = Math.round(size * 0.52);

  return (
    <Box
      sx={{
        width: size,
        height: size,
        borderRadius: 2,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
        bgcolor: `${color}18`,
        color,
      }}
    >
      <Icon sx={{ fontSize: iconSize }} />
    </Box>
  );
}

export function CategoryLabel({
  name,
  icon,
  colorIndex = 0,
}: {
  name: string;
  icon?: string | null;
  colorIndex?: number;
}) {
  return (
    <Box display="flex" alignItems="center" gap={1.25}>
      <CategoryIconBadge name={name} icon={icon} colorIndex={colorIndex} size={32} />
      <Box component="span" sx={{ fontWeight: 600 }}>
        {name}
      </Box>
    </Box>
  );
}

/** Icon mặc định cho ô chọn danh mục */
export const CategoryFieldIcon = PaymentsOutlined;

export { palette };
