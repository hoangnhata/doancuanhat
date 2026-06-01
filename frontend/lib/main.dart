import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/router/app_router.dart';
import 'package:expense_manager/core/di/injection.dart';
import 'package:expense_manager/core/providers/app_providers.dart';
import 'package:expense_manager/core/services/notification_service.dart';
import 'package:expense_manager/presentation/screens/splash_screen.dart';

void _listenConnectivitySync() {
  Timer? syncDebounce;
  Connectivity().onConnectivityChanged.listen((_) {
    syncDebounce?.cancel();
    syncDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(syncService.syncAllIfOnline());
    });
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Không await DI trước runApp: emulator báo "Skipped N frames" vì frame đầu bị chặn quá lâu.
  runApp(const _BootstrapApp());
}

/// Màn hóa tải tối thiểu (không GoogleFonts) → frame đầu nhẹ; sau khi DI xong mới vào app đầy đủ.
class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  bool _ready = false;
  Object? _bootstrapError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      await initDependencies();
      await NotificationService.init();
      if (!kIsWeb) {
        try {
          if (await localStorage.isDailyReminderEnabled()) {
            final h = await localStorage.getDailyReminderHour();
            final m = await localStorage.getDailyReminderMinute();
            await NotificationService.scheduleDailyReminder(hour: h, minute: m);
          }
        } catch (_) {}
      }
      _listenConnectivitySync();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _bootstrapError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không khởi động được app.\n$_bootstrapError',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.gradientStart, AppColors.background],
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          ),
        ),
      );
    }
    return const ProviderScope(
      child: ExpenseManagerApp(),
    );
  }
}

class ExpenseManagerApp extends ConsumerWidget {
  const ExpenseManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Quản lý Chi tiêu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      // Dùng home thay vì initialRoute + onGenerateRoute: tránh edge case Navigator; splash luôn là widget gốc.
      home: const SplashScreen(),
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
