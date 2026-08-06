import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../providers/core_providers.dart';
import '../../widgets/state_views.dart';

/// Section 5.3 — recovery in two steps: ask for a code, then set a new password.
///
/// With no mail server in the project the backend hands the code straight back
/// (development mode); in production the same screen would simply say
/// «کد به ایمیل شما ارسال شد».
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _codeRequested = false;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_emailKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final token = await ref.read(authRepositoryProvider).requestPasswordReset(_email.text);
      if (!mounted) return;
      setState(() {
        _codeRequested = true;
        if (token != null) _token.text = token;
      });
      showMessage(
        context,
        token == null
            ? 'اگر این ایمیل ثبت شده باشد، کد بازیابی برایش ارسال می‌شود.'
            : 'کد بازیابی ساخته شد.',
      );
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_resetKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(token: _token.text.trim(), password: _password.text);
      if (!mounted) return;
      showMessage(context, 'رمز عبور عوض شد. حالا وارد شو.');
      context.pop();
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بازیابی رمز عبور')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ایمیل حسابت را بنویس تا کد بازیابی بسازیم.',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: 20),
              Form(
                key: _emailKey,
                child: TextFormField(
                  controller: _email,
                  enabled: !_codeRequested,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'ایمیل',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: Validators.email,
                ),
              ),
              const SizedBox(height: 14),
              if (!_codeRequested)
                FilledButton(
                  onPressed: _busy ? null : _requestCode,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('دریافت کد بازیابی'),
                )
              else ...[
                Form(
                  key: _resetKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _token,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'کد بازیابی',
                          prefixIcon: Icon(Icons.vpn_key_outlined),
                        ),
                        validator: (value) => Validators.required(value, field: 'کد بازیابی'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'رمز عبور تازه',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _reset,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              )
                            : const Text('ثبت رمز تازه'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy ? null : () => setState(() => _codeRequested = false),
                        child: const Text('ایمیل را عوض می‌کنم'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
