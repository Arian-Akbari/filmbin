import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/state_views.dart';

/// Section 5.2 — sign in with email and password. «مرا به خاطر بسپار» decides
/// whether the session lasts a month or a day.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = true;
  bool _obscure = true;
  bool _busy = false;
  Map<String, String> _serverErrors = const {};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(email: _email.text, password: _password.text, rememberMe: _rememberMe);
      if (!mounted) return;
      showMessage(context, 'خوش آمدید!');
      context.canPop() ? context.pop() : context.go('/home');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _serverErrors = error.fields);
      _formKey.currentState!.validate();
      showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.movie_filter_rounded, size: 52, color: context.scheme.primary),
                const SizedBox(height: 18),
                Text(
                  'خوش آمدید',
                  style: context.text.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'برای ثبت فعالیت‌هایت وارد شو',
                  style: context.text.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
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
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) =>
                      _serverErrors['password'] ??
                      Validators.required(value, field: 'رمز عبور'),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) => setState(() => _rememberMe = value ?? true),
                    ),
                    Expanded(
                      child: Text('یک ماه مرا به خاطر بسپار', style: context.text.bodySmall),
                    ),
                    TextButton(
                      onPressed: () => context.push('/forgot'),
                      child: const Text('رمز را فراموش کردم'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('ورود'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy ? null : () => context.push('/register'),
                  child: const Text('ساخت حساب تازه'),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () {
                    ref.read(authControllerProvider.notifier).continueAsGuest();
                    context.canPop() ? context.pop() : context.go('/home');
                  },
                  child: const Text('فعلاً به‌عنوان مهمان می‌گردم'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
