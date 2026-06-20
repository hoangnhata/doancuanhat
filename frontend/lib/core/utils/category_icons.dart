import 'package:flutter/material.dart';

const categoryColors = [
  Color(0xFF0288D1),
  Color(0xFF7B1FA2),
  Color(0xFF00897B),
  Color(0xFFF57C00),
  Color(0xFFC2185B),
  Color(0xFF3949AB),
  Color(0xFF689F38),
  Color(0xFFD84315),
];

Color categoryColor(int index) => categoryColors[index % categoryColors.length];

IconData categoryIconData({required String name, String? icon}) {
  final n = name.toLowerCase();
  if (n.contains('ăn uống') || n.contains('food')) return Icons.restaurant_rounded;
  if (n.contains('di chuyển') || n.contains('grab') || n.contains('xe')) return Icons.directions_car_rounded;
  if (n.contains('nhà ở') || n.contains('housing')) return Icons.home_rounded;
  if (n.contains('hóa đơn') || n.contains('bill')) return Icons.receipt_long_rounded;
  if (n.contains('mua sắm') || n.contains('shopping')) return Icons.shopping_bag_rounded;
  if (n.contains('giải trí')) return Icons.movie_rounded;
  if (n.contains('du lịch') || n.contains('travel')) return Icons.luggage_rounded;
  if (n.contains('giáo dục') || n.contains('education')) return Icons.menu_book_rounded;
  if (n.contains('sức khỏe') || n.contains('y tế')) return Icons.medical_services_rounded;
  if (n.contains('gia đình') || n.contains('family')) return Icons.family_restroom_rounded;
  if (n.contains('thú cưng') || n.contains('pet')) return Icons.pets_rounded;
  if (n.contains('quà tặng') || n.contains('gift')) return Icons.card_giftcard_rounded;
  if (n.contains('từ thiện') || n.contains('charity')) return Icons.volunteer_activism_rounded;
  if (n.contains('lương') || n.contains('salary')) return Icons.account_balance_wallet_rounded;
  if (n.contains('thưởng') || n.contains('bonus')) return Icons.emoji_events_rounded;
  if (n.contains('freelance')) return Icons.laptop_mac_rounded;
  if (n.contains('đầu tư') || n.contains('invest')) return Icons.trending_up_rounded;
  if (n.contains('bán hàng') || n.contains('sales')) return Icons.storefront_rounded;
  if (n.contains('thu nhập khác')) return Icons.more_horiz_rounded;
  if (n.contains('khác')) return Icons.push_pin_rounded;
  return Icons.category_rounded;
}
