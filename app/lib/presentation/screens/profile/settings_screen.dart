import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/state_views.dart';

/// Sections 5.15, 8.5 and 8.8 — the handful of choices that change how the app
/// looks and how much data it spends.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final auth = ref.watch(authControllerProvider);
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _Group(
            title: 'نمایش',
            children: [
              RadioGroup<ThemeMode>(
                groupValue: settings.themeMode,
                onChanged: (mode) => controller.setThemeMode(mode ?? ThemeMode.system),
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      title: Text('پیروی از سیستم'),
                    ),
                    RadioListTile<ThemeMode>(value: ThemeMode.dark, title: Text('تیره')),
                    RadioListTile<ThemeMode>(value: ThemeMode.light, title: Text('روشن')),
                  ],
                ),
              ),
            ],
          ),
          _Group(
            title: 'خواندن نظرها',
            children: [
              SwitchListTile(
                value: settings.hideSpoilers,
                onChanged: controller.setHideSpoilers,
                title: const Text('پنهان کردن نظرهای دارای اسپویل'),
                subtitle: Text(
                  'متن این نظرها تا وقتی خودت نخواهی باز نمی‌شود (بخش ۵.۱۵).',
                  style: context.text.labelSmall,
                ),
              ),
            ],
          ),
          _Group(
            title: 'مصرف داده',
            children: [
              SwitchListTile(
                value: settings.dataSaver,
                onChanged: controller.setDataSaver,
                title: const Text('کم‌مصرف'),
                subtitle: Text(
                  'به‌جای پوستر بزرگ، نسخهٔ کوچک تصویرها بارگیری می‌شود (بخش ۸.۸).',
                  style: context.text.labelSmall,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('پاک کردن حافظهٔ نهان این دستگاه'),
                subtitle: Text(
                  'اطلاعات ذخیره‌شدهٔ آفلاین دوباره از سرور گرفته می‌شود.',
                  style: context.text.labelSmall,
                ),
                onTap: () async {
                  ref.read(apiClientProvider).clearCache();
                  await ref.read(localDatabaseProvider).clearCache();
                  if (context.mounted) showMessage(context, 'حافظهٔ نهان پاک شد.');
                },
              ),
            ],
          ),
          _Group(
            title: 'حساب',
            children: [
              if (auth.isAuthenticated) ...[
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('ویرایش پروفایل'),
                  trailing: const Icon(
                    Icons.chevron_left_rounded,
                    textDirection: TextDirection.ltr,
                  ),
                  onTap: () => context.push('/profile/edit'),
                ),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: context.scheme.error),
                  title: Text('خروج از حساب', style: TextStyle(color: context.scheme.error)),
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go('/home');
                  },
                ),
              ] else
                ListTile(
                  leading: const Icon(Icons.login_rounded),
                  title: const Text('ورود یا ثبت‌نام'),
                  trailing: const Icon(
                    Icons.chevron_left_rounded,
                    textDirection: TextDirection.ltr,
                  ),
                  onTap: () => context.push('/login'),
                ),
            ],
          ),
          _Group(
            title: 'دربارهٔ برنامه',
            children: [
              ListTile(
                leading: const Icon(Icons.movie_filter_rounded),
                title: const Text('فیلم‌بین'),
                subtitle: Text(
                  'مدیریت و دنبال کردن فیلم و سریال — پروژهٔ درس برنامه‌سازی موبایل',
                  style: context.text.labelSmall,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('نشانی سرویس'),
                subtitle: Text(
                  config.baseUrl,
                  textDirection: TextDirection.ltr,
                  style: context.text.labelSmall,
                ),
              ),
              ListTile(
                leading: Icon(
                  config.pinningEnabled
                      ? Icons.verified_user_outlined
                      : Icons.lock_open_rounded,
                ),
                title: const Text('اتصال امن'),
                subtitle: Text(
                  config.pinningEnabled
                      ? 'گواهی سرور سنجاق شده است (بخش ۸.۳).'
                      : 'در حالت توسعه روی HTTP و بدون سنجاق گواهی اجرا می‌شود.',
                  style: context.text.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Text(title, style: context.text.titleMedium),
          ),
          Card(child: Column(children: children)),
        ],
      ),
    );
  }
}
