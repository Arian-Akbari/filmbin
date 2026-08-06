import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/state_views.dart';

/// Section 5.1 — full name, username, email, password and an optional bio.
/// The server has the final say on duplicates, and its `fields` map is shown
/// under the offending input.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _bio = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  Map<String, String> _serverErrors = const {};

  @override
  void dispose() {
    for (final controller in [_fullName, _username, _email, _password, _confirm, _bio]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            fullName: _fullName.text,
            username: _username.text,
            email: _email.text,
            password: _password.text,
            bio: _bio.text,
          );
      if (!mounted) return;
      showMessage(context, 'حساب شما ساخته شد. خوش آمدید!');
      context.go('/home');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _serverErrors = {
          ...error.fields,
          if (error.code == 'EMAIL_TAKEN') 'email': error.message,
          if (error.code == 'USERNAME_TAKEN') 'username': error.message,
        };
      });
      _formKey.currentState!.validate();
      showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ساخت حساب تازه')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('چند ثانیه بیشتر طول نمی‌کشد', style: context.text.bodySmall),
                const SizedBox(height: 20),
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
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    helperText: 'حروف انگلیسی، ارقام و «_»',
                  ),
                  validator: (value) => _serverErrors['username'] ?? Validators.username(value),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'ایمیل',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) => _serverErrors['email'] ?? Validators.email(value),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'رمز عبور',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (value) => _serverErrors['password'] ?? Validators.password(value),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'تکرار رمز عبور',
                    prefixIcon: Icon(Icons.lock_reset_rounded),
                  ),
                  validator: (value) => Validators.confirm(value, _password.text),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bio,
                  maxLines: 2,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'دربارهٔ من (اختیاری)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('ثبت‌نام'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('حساب دارم؛ وارد می‌شوم'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
