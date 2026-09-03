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
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final otp = TextEditingController();

  bool registerMode = false;
  bool busy = false;
  bool rememberMe = true;
  dynamic challengeId;
  String? message;

  @override
  void initState() {
    super.initState();
    api = AuthApi(widget.baseUrl);
  }

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    confirmPassword.dispose();
    otp.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('invalid_credentials')) return 'شماره موبایل یا رمز عبور صحیح نیست.';
    if (text.contains('phone_exists')) return 'این شماره قبلاً ثبت‌نام شده است.';
    if (text.contains('phone_not_verified')) return 'شماره موبایل هنوز تایید نشده است.';
    if (text.contains('invalid_or_expired_otp')) return 'کد تایید اشتباه یا منقضی شده است.';
    if (text.contains('account_suspended')) return 'این حساب در حال حاضر غیرفعال است.';
    return 'ارتباط با سرور انجام نشد. اتصال اینترنت و آدرس سرور را بررسی کنید.';
  }

  Future<void> _submit() async {
    if (busy) return;

    final p = phone.text.trim();
    final pass = password.text;

    if (p.isEmpty || pass.length < 8) {
      setState(() => message = 'شماره موبایل و رمز حداقل ۸ کاراکتری را وارد کنید.');
      return;
    }

    if (registerMode && challengeId == null && pass != confirmPassword.text) {
      setState(() => message = 'تکرار رمز عبور با رمز اصلی یکسان نیست.');
      return;
    }

    setState(() {
      busy = true;
      message = null;
    });

    try {
      if (!registerMode) {
        final result = await api.login(phone: p, password: pass);
        final token = result['token']?.toString();
        if (token == null || token.isEmpty) throw Exception('missing_token');
        widget.onAuthenticated(token, rememberMe);
        return;
      }

      if (challengeId == null) {
        final result = await api.register(phone: p, password: pass);
        final otpData = result['otp'];
        challengeId = otpData is Map ? otpData['challengeId'] : null;
        if (challengeId == null) throw Exception('missing_challenge');
        setState(() => message = 'کد تایید برای شماره شما ارسال شد.');
      } else {
        if (otp.text.trim().length < 4) {
          setState(() => message = 'کد تایید را وارد کنید.');
          return;
        }
        final result = await api.verifyPhone(
          phone: p,
          challengeId: challengeId,
          code: otp.text.trim(),
        );
        final token = result['token']?.toString();
        if (token == null || token.isEmpty) throw Exception('missing_token');
        widget.onAuthenticated(token, true);
      }
    } catch (e) {
      if (mounted) setState(() => message = _friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final phoneController = TextEditingController(text: phone.text);
    final codeController = TextEditingController();
    final newPassController = TextEditingController();
    dynamic resetChallenge;
    bool requested = false;
    String? localError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            Future<void> request() async {
              final p = phoneController.text.trim();
              if (p.isEmpty) {
                setLocal(() => localError = 'شماره موبایل را وارد کنید.');
                return;
              }
              try {
                final result = await api.forgotPasswordRequest(phone: p);
                final otpData = result['otp'];
                resetChallenge = otpData is Map ? otpData['challengeId'] : null;
                setLocal(() {
                  requested = true;
                  localError = resetChallenge == null
                      ? 'اگر این شماره ثبت شده باشد، کد بازیابی ارسال می‌شود.'
                      : 'کد بازیابی ارسال شد.';
                });
              } catch (_) {
                setLocal(() => localError = 'ارسال کد بازیابی انجام نشد.');
              }
            }

            Future<void> confirm() async {
              if (resetChallenge == null) {
                setLocal(() => localError = 'ابتدا کد بازیابی را درخواست کنید.');
                return;
              }
              if (newPassController.text.length < 8) {
                setLocal(() => localError = 'رمز جدید حداقل ۸ کاراکتر باشد.');
                return;
              }
              try {
                await api.forgotPasswordConfirm(
                  phone: phoneController.text.trim(),
                  challengeId: resetChallenge,
                  code: codeController.text.trim(),
                  newPassword: newPassController.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                setState(() => message = 'رمز عبور با موفقیت تغییر کرد.');
              } catch (_) {
                setLocal(() => localError = 'کد بازیابی اشتباه یا منقضی شده است.');
              }
            }

            return AlertDialog(
              title: const Text('بازیابی رمز عبور'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AuthField(
                      controller: phoneController,
                      label: 'شماره موبایل',
                      icon: Icons.phone_iphone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    if (requested) ...[
                      const SizedBox(height: 10),
                      _AuthField(
                        controller: codeController,
                        label: 'کد تایید',
                        icon: Icons.verified_user_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      _AuthField(
                        controller: newPassController,
                        label: 'رمز عبور جدید',
                        icon: Icons.lock_reset_rounded,
                        obscure: true,
                      ),
                    ],
                    if (localError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        localError!,
                        style: const TextStyle(color: MtColors.red, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: requested ? confirm : request,
                  child: Text(requested ? 'ثبت رمز جدید' : 'ارسال کد'),
                ),
              ],
            );
          },
        );
      },
    );

    phoneController.dispose();
    codeController.dispose();
    newPassController.dispose();
  }

  void _switchMode(bool value) {
    if (busy) return;
    setState(() {
      registerMode = value;
      challengeId = null;
      otp.clear();
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
                              ? 'حساب خود را برای مدیریت و رهگیری هوشمند خودرو بسازید'
                              : 'مدیریت و رهگیری هوشمند خودرو',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 28),
                        _AuthField(
                          controller: phone,
                          label: 'شماره موبایل',
                          icon: Icons.phone_iphone_rounded,
                          enabled: challengeId == null,
                          keyboardType: TextInputType.phone,
                        ),
                        if (registerMode && challengeId != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _AuthField(
                                  controller: otp,
                                  label: 'کد تایید',
                                  icon: Icons.verified_user_outlined,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 130,
                                child: MtRedButton(
                                  label: 'ارسال مجدد',
                                  outlined: true,
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          try {
                                            final result = await api.register(
                                              phone: phone.text.trim(),
                                              password: password.text,
                                            );
                                            final otpData = result['otp'];
                                            setState(() {
                                              challengeId = otpData is Map
                                                  ? otpData['challengeId']
                                                  : challengeId;
                                              message = 'کد تایید دوباره ارسال شد.';
                                            });
                                          } catch (e) {
                                            setState(() => message = _friendlyError(e));
                                          }
                                        },
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        _AuthField(
                          controller: password,
                          label: 'رمز عبور',
                          icon: Icons.lock_outline_rounded,
                          obscure: true,
                          enabled: challengeId == null,
                        ),
                        if (registerMode && challengeId == null) ...[
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
                                onChanged: (v) => setState(() => rememberMe = v ?? true),
                              ),
                              const Text('مرا به خاطر بسپار'),
                              const Spacer(),
                              TextButton(
                                onPressed: busy ? null : _forgotPassword,
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
                                  ? (challengeId == null
                                      ? 'ادامه و دریافت کد تایید'
                                      : 'تایید و تکمیل ثبت نام')
                                  : 'ورود',
                          onPressed: busy ? null : _submit,
                          height: 58,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.withOpacity(.25))),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('یا', style: TextStyle(color: Colors.grey)),
                            ),
                            Expanded(child: Divider(color: Colors.grey.withOpacity(.25))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => _switchMode(!registerMode),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: registerMode ? 'حساب دارم؟ ' : 'حساب ندارم؟ ',
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
  final bool enabled;
  final TextInputType? keyboardType;

  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.enabled = true,
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
      enabled: widget.enabled,
      obscureText: obscure,
      keyboardType: widget.keyboardType,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.obscure
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => obscure = !obscure),
              )
            : null,
        suffixIcon: Icon(widget.icon),
      ),
    );
  }
}
