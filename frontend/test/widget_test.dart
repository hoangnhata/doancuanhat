import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/presentation/widgets/common/empty_state.dart';

void main() {
  testWidgets('EmptyState displays title', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.inbox_rounded,
            title: 'Chưa có dữ liệu',
          ),
        ),
      ),
    );
    expect(find.text('Chưa có dữ liệu'), findsOneWidget);
  });
}
