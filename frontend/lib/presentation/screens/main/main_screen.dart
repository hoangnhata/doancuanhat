import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/utils/haptic_utils.dart';
import 'package:expense_manager/presentation/screens/main/chat_tab.dart';
import 'package:expense_manager/presentation/screens/main/dashboard_tab.dart';
import 'package:expense_manager/presentation/screens/main/transactions_tab.dart';
import 'package:expense_manager/presentation/screens/main/settings_tab.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final _tabs = [
    const DashboardTab(),
    const TransactionsTab(),
    const ChatTab(),
    const SettingsTab(),
  ];

  // Vị trí FAB dạng "floating" cho phép người dùng tự kéo thả như AssistiveTouch.
  // Offset tính theo hệ tọa độ của body(Stack) - gốc (0,0) là góc trên-trái.
  Offset? _fabPos;
  bool _fabUserMoved = false;
  bool _fabDragging = false;
  bool _fabShouldIgnoreTap = false;
  bool _fabInitScheduled = false;

  // Biên giới clamp/snap cho FAB (theo kích thước của body(Stack)).
  Size? _fabBoundarySize;
  double _fabKeyboardHeight = 0;

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = keyboardHeight > 0;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          const fabSize = 56.0;
          const margin = 16.0;

          _fabBoundarySize = Size(constraints.maxWidth, constraints.maxHeight);
          // Chỉ dùng keyboard inset khi bàn phím thực sự mở.
          final effectiveKeyboardHeight =
              keyboardOpen ? keyboardHeight : 0.0;
          _fabKeyboardHeight = effectiveKeyboardHeight;

          // Mặc định: góc phải dưới (chuẩn UX), tránh đè lên nội dung chính.
          final defaultX = constraints.maxWidth - fabSize - margin;
          final defaultY = constraints.maxHeight - effectiveKeyboardHeight - fabSize - margin;
          final defaultXClamped =
              defaultX.clamp(margin, constraints.maxWidth - fabSize - margin);

          final safeTopLimit = margin;
          final safeBottomLimitRaw =
              constraints.maxHeight - effectiveKeyboardHeight - margin - fabSize;
          final safeBottomLimit = safeBottomLimitRaw < safeTopLimit
              ? safeTopLimit
              : safeBottomLimitRaw;
          final defaultYClamped = defaultY.clamp(safeTopLimit, safeBottomLimit);

          // Thiết lập ban đầu một lần (tránh setState trong build).
          if (_fabPos == null && !_fabInitScheduled) {
            _fabInitScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _fabPos = Offset(defaultXClamped, defaultYClamped);
              });
            });
          }

          final currentPos = _fabPos ?? Offset(defaultX, defaultY);
          final clampedX = currentPos.dx
              .clamp(margin, constraints.maxWidth - fabSize - margin);
          final clampedY =
              currentPos.dy.clamp(safeTopLimit, safeBottomLimit);

          // Nếu user chưa kéo thả, giữ FAB ở vị trí mặc định theo tab/keyboard.
          final posToUse = _fabUserMoved
              ? Offset(clampedX, clampedY)
              : Offset(defaultXClamped, defaultYClamped);

          final Widget fabWidget = _fabDragging
              ? Positioned(
                  left: posToUse.dx,
                  top: posToUse.dy,
                  child: _buildFab(context),
                )
              : AnimatedPositioned(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  left: posToUse.dx,
                  top: posToUse.dy,
                  child: _buildFab(context),
                );

          return Stack(
            children: [
              IndexedStack(index: _currentIndex, children: _tabs),
              // Ẩn FAB ở tab Chat (có input riêng) và Cài đặt.
              if (_currentIndex != 2 && _currentIndex != 3) fabWidget,
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          boxShadow: AppColors.softShadow,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Expanded(child: _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Trang chủ',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                )),
                Expanded(child: _NavItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Giao dịch',
                  isSelected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                )),
                Expanded(child: _NavItem(
                  icon: Icons.smart_toy_rounded,
                  label: 'Trợ lý AI',
                  isSelected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                )),
                Expanded(child: _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Cài đặt',
                  isSelected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                )),
              ],
            ),
          ),
        ),
      ),
      // FAB được render trong body (Stack) để tự dịch chuyển/cho phép kéo thả.
    );
  }

  Widget _buildFab(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (_) {
        _fabShouldIgnoreTap = false;
        _fabDragging = false;
      },
      onPanStart: (_) {
        // Không set dragging ở đây để tránh tap bị coi là kéo.
        // Chỉ coi là kéo khi có movement đủ lớn trong onPanUpdate.
      },
      onPanUpdate: (details) {
        final delta = details.delta;
        if (delta.distance > 2) {
          _fabShouldIgnoreTap = true;
          _fabDragging = true;
        }

        // Nếu chưa có pos (lúc rất sớm), bỏ qua update.
        if (_fabPos == null) return;

        final size = _fabBoundarySize;
        if (size == null) return;
        const fabSize = 56.0;
        const margin = 16.0;

        final safeBottomLimitRaw =
            size.height - _fabKeyboardHeight - margin - fabSize;
        final safeBottomLimit = safeBottomLimitRaw < margin
            ? margin
            : safeBottomLimitRaw;
        final safeTopLimit = margin;

        setState(() {
          final nextX = (_fabPos!.dx + delta.dx)
              .clamp(margin, size.width - fabSize - margin);
          final nextY = (_fabPos!.dy + delta.dy)
              .clamp(safeTopLimit, safeBottomLimit);
          _fabPos = Offset(nextX, nextY);
          _fabUserMoved = true;
        });
      },
      onPanEnd: (_) {
        final wasDragging = _fabDragging;
        _fabDragging = false;

        // Snap ngang sang trái/phải gần nhất để trông "iPhone-like" hơn.
        final size = _fabBoundarySize;
        if (!wasDragging || size == null || _fabPos == null) return;
        const fabSize = 56.0;
        const margin = 16.0;
        final safeBottomLimitRaw =
            size.height - _fabKeyboardHeight - margin - fabSize;
        final safeBottomLimit = safeBottomLimitRaw < margin
            ? margin
            : safeBottomLimitRaw;

        final snapToLeft = _fabPos!.dx + fabSize / 2 < size.width / 2;
        final snappedX =
            snapToLeft ? margin : size.width - fabSize - margin;
        final snappedY =
            _fabPos!.dy.clamp(margin, safeBottomLimit);

        setState(() {
          _fabPos = Offset(snappedX, snappedY);
          _fabUserMoved = true;
        });
      },
      child: SizedBox(
        width: 56,
        height: 56,
        child: FloatingActionButton(
          onPressed: () {
            // Nếu vừa kéo thì không trigger action.
            if (_fabShouldIgnoreTap) return;

            HapticUtils.medium();
            Navigator.pushNamed(context, AppRouter.addTransaction).then((_) {
              ref
                  .read(transactionListRefreshTriggerProvider.notifier)
                  .state++;
            });
          },
          backgroundColor: AppColors.primary,
          elevation: 4,
          child: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticUtils.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
