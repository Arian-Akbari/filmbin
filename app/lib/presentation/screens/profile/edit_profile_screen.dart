import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/state_views.dart';

/// Section 5.4 — edit the profile: name, username, bio, picture and password.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _fullName = TextEditingController(
    text: ref.read(currentUserProvider)?.fullName ?? '',
  );
  late final _username = TextEditingController(
    text: ref.read(currentUserProvider)?.username ?? '',
  );
  late final _bio = TextEditingController(text: ref.read(currentUserProvider)?.bio ?? '');
  bool _busy = false;
  bool _uploading = false;
  Map<String, String> _serverErrors = const {};

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _serverErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      final user = await ref
          .read(userRepositoryProvider)
          .updateProfile(
            fullName: _fullName.text.trim(),
            username: _username.text.trim(),
            bio: _bio.text.trim(),
          );
      ref.read(authControllerProvider.notifier).updateUser(user);
      if (!mounted) return;
      showMessage(context, 'پروفایل به‌روز شد.');
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _serverErrors = {
          ...error.fields,
          if (error.code == 'USERNAME_TAKEN') 'username': error.message,
        };
      });
      _formKey.currentState!.validate();
      showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Section 5.4 — the picture comes from the gallery and is resized on the way
  /// out so a 12-megapixel photo never becomes a 12-megabyte upload.
  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      await ref.read(userRepositoryProvider).uploadAvatar(picked.path);
      await ref.read(authControllerProvider.notifier).refreshProfile();
      if (mounted) showMessage(context, 'تصویر پروفایل عوض شد.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _changePassword() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _PasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(
          icon: Icons.person_off_outlined,
          message: 'برای ویرایش پروفایل باید وارد شده باشی.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ویرایش پروفایل')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      AppAvatar(url: user.avatarUrl, initial: user.initial, size: 104),
                      Material(
                        color: context.scheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploading ? null : _pickAvatar,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _uploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : Icon(
                                    Icons.photo_camera_rounded,
                                    size: 16,
                                    color: context.scheme.onPrimary,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                TextFormField(
                  controller: _fullName,
                  decoration: const InputDecoration(
                    labelText: 'نام و نام خانوادگی',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) =>
                      _serverErrors['full_name'] ?? Validators.fullName(value),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _username,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'نام کاربری',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) => _serverErrors['username'] ?? Validators.username(value),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bio,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'دربارهٔ من',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 6),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('ذخیرهٔ تغییرها'),
                ),
                const SizedBox(height: 22),
                Divider(color: context.colors.outline),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.password_rounded),
                  title: const Text('تغییر رمز عبور'),
                  subtitle: Text(
                    'برای تغییر رمز، رمز فعلی هم لازم است.',
                    style: context.text.labelSmall,
                  ),
                  trailing: const Icon(
                    Icons.chevron_left_rounded,
                    textDirection: TextDirection.ltr,
                  ),
                  onTap: _changePassword,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .changePassword(currentPassword: _current.text, newPassword: _next.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessage(context, 'رمز عبور عوض شد. نشست‌های دیگر بسته شدند.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('تغییر رمز عبور', style: context.text.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _current,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'رمز فعلی'),
              validator: (value) => Validators.required(value, field: 'رمز فعلی'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'رمز تازه'),
              validator: Validators.password,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'تکرار رمز تازه'),
              validator: (value) => Validators.confirm(value, _next.text),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Text('ثبت رمز تازه'),
            ),
          ],
        ),
      ),
    );
  }
}
