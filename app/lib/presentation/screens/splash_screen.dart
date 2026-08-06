import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/core_providers.dart';

/// First frame: restores the stored session (section 5.2) and replays anything
/// the user did while offline (section 8.4) before handing over to the app.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await ref.read(authControllerProvider.notifier).restore();
    if (ref.read(authControllerProvider).isAuthenticated) {
      unawaited(ref.read(trackingRepositoryProvider).flushOutbox());
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: context.scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(Icons.movie_filter_rounded, size: 46, color: context.scheme.primary),
            ),
            const SizedBox(height: 22),
            Text('فیلم‌بین', style: context.text.displaySmall),
            const SizedBox(height: 6),
            Text('فیلم‌ها و سریال‌هایت را دنبال کن', style: context.text.bodySmall),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: context.scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
