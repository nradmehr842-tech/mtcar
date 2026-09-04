import 'package:flutter/material.dart';
import '../app/mtcar_theme.dart';
import '../services/auth_api.dart';
import '../widgets/mtcar_design.dart';

class AuthScreen extends StatefulWidget {
  final String baseUrl;
  final bool darkMode;
  final VoidCallback onTheme;
  final void Function(String token, bool remember) onAuthenticated;

  const AuthScreen({
    super.key,
    required this.baseUrl,
    required this.darkMode,
    required this.onTheme,
    required this.onAuthenticated,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late final AuthApi api;
  final username = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  bool registerMode = false;
  bool busy = false;
  bool rememberMe = true;
  String? message;

  @override
  void initState() {
    super.initState();
    api = AuthApi(widget.baseUrl);
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('invalid_credentials')) {
      return 'نام کاربری یا رمز عبور صحیح نیست.';
    }
    if (text.contains('username_exists')) {
      return 'این نام کاربری قبلاً ثبت شده است.';
    }
    if (text.contains('invalid_username')) {
      return 'نام کاربری باید ۳ تا ۴۰ کاراکتر و شامل حروف، عدد، نقطه، خط تیره یا زیرخط باشد.';
    }
    if (text.contains('password_confirmation_mismatch')) {
      return 'تکرار رمز عبور با رمز اصلی یکسان نیست.';
    }
    if (text.contains('account_suspended')) {
      return 'این حساب در حال حاضر غیرفعال است.';
    }
    if (text.contains('Password must contain at least 8 characters')) {
      return 'رمز عبور باید حداقل ۸ کاراکتر باشد.';
    }
    return 'ارتباط با سرور انجام نشد. اتصال اینترنت و آدرس سرور را بررسی کنید.';
  }

  Future<void> _submit() async {
    if (busy) return;

    final u = username.text.trim();
    final pass = password.text;

    if (u.length < 3) {
      setState(() => message = 'نام کاربری حداقل ۳ کاراکتر باشد.');
      return;
    }
    if (pass.length < 8) {
      setState(() => message = 'رمز عبور حداقل ۸ کاراکتر باشد.');
      return;
    }
    if (registerMode && pass != confirmPassword.text) {
      setState(() => message = 'تکرار رمز عبور با رمز اصلی یکسان نیست.');
      return;
    }

    setState(() {
      busy = true;
      message = null;
    });

    try {
      final result = registerMode
          ? await api.register(
              username: u,
              password: pass,
              confirmPassword: confirmPassword.text,
            )
          : await api.login(
              username: u,
              password: pass,
            );

      final token = result['token']?.toString();
      if (token == null || token.isEmpty) throw Exception('missing_token');
      widget.onAuthenticated(token, registerMode ? true : rememberMe);
    } catch (e) {
      if (mounted) setState(() => message = _friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _switchMode(bool value) {
    if (busy) return;
    setState(() {
      registerMode = value;
      confirmPassword.clear();
      message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          MtPremiumHeader(
            onTheme: widget.onTheme,
            darkMode: widget.darkMode,
            notificationCount: 0,
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: MtCard(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          registerMode ? 'ثبت نام در MTcar' : 'ورود به MTcar',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          registerMode
                              ? 'بدون پیامک؛ فقط نام کاربری و رمز عبور'
                              : 'مدیریت و رهگیری هوشمند خودرو',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 28),
                        _AuthField(
                          controller: username,
                          label: 'نام کاربری',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 12),
                        _AuthField(
                          controller: password,
                          label: 'رمز عبور',
                          icon: Icons.lock_outline_rounded,
                          obscure: true,
                        ),
                        if (registerMode) ...[
                          const SizedBox(height: 12),
                          _AuthField(
                            controller: confirmPassword,
                            label: 'تکرار رمز عبور',
                            icon: Icons.lock_outline_rounded,
                            obscure: true,
                          ),
                        ],
                        if (!registerMode) ...[
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Checkbox(
                                value: rememberMe,
                                activeColor: MtColors.red,
                                onChanged: (v) =>
                                    setState(() => rememberMe = v ?? true),
                              ),
                              const Text('مرا به خاطر بسپار'),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('بازیابی حساب'),
                                      content: const Text(
                                        'فعلاً بازیابی خودکار با پیامک غیرفعال است. برای بازیابی رمز از پشتیبانی MTcar استفاده کنید.',
                                      ),
                                      actions: [
                                        FilledButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('باشه'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text(
                                  'رمز عبور را فراموش کرده‌ام',
                                  style: TextStyle(color: MtColors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (message != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: MtColors.red.withOpacity(.06),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              message!,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        MtRedButton(
                          label: busy
                              ? 'لطفاً صبر کنید...'
                              : registerMode
                                  ? 'ثبت نام'
                                  : 'ورود',
                          onPressed: busy ? null : _submit,
                          height: 58,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.grey.withOpacity(.25),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'یا',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.grey.withOpacity(.25),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => _switchMode(!registerMode),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: registerMode
                                      ? 'حساب دارم؟ '
                                      : 'حساب ندارم؟ ',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                TextSpan(
                                  text: registerMode ? 'ورود' : 'ثبت نام',
                                  style: const TextStyle(
                                    color: MtColors.red,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (registerMode) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'با ثبت نام، قوانین و حریم خصوصی MTcar را می‌پذیرید.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;

  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  late bool obscure;

  @override
  void initState() {
    super.initState();
    obscure = widget.obscure;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: obscure,
      keyboardType: widget.keyboardType,
      textDirection: TextDirection.rtl,
      autocorrect: false,
      enableSuggestions: !widget.obscure,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.obscure
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => obscure = !obscure),
              )
            : null,
        suffixIcon: Icon(widget.icon),
      ),
    );
  }
}
