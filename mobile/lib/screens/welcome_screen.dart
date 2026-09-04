import 'package:flutter/material.dart';
import '../app/mtcar_theme.dart';
import '../widgets/mtcar_design.dart';

class WelcomeScreen extends StatelessWidget {
  final bool darkMode;
  final VoidCallback onTheme;
  final VoidCallback onStart;
  final VoidCallback onLogin;

  const WelcomeScreen({
    super.key,
    required this.darkMode,
    required this.onTheme,
    required this.onStart,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          MtPremiumHeader(
            onTheme: onTheme,
            darkMode: darkMode,
            notificationCount: 0,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'به '),
                      const TextSpan(
                        text: 'MTcar',
                        style: TextStyle(color: MtColors.red),
                      ),
                      const TextSpan(text: ' خوش آمدید'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'راه‌اندازی اولیه سامانه رهگیری هوشمند خودرو',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 24),
                MtCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    children: const [
                      _SetupStep(
                        number: '1',
                        icon: Icons.person_outline_rounded,
                        title: 'ثبت‌نام یا ورود',
                        subtitle: 'اطلاعات خود را وارد کنید یا وارد حساب کاربری شوید',
                      ),
                      MtDivider(),
                      _SetupStep(
                        number: '2',
                        icon: Icons.memory_rounded,
                        title: 'افزودن دستگاه و IMEI',
                        subtitle: 'ردیاب خود را اضافه کرده و شناسه IMEI را ثبت کنید',
                      ),
                      MtDivider(),
                      _SetupStep(
                        number: '3',
                        icon: Icons.shield_outlined,
                        title: 'فعال‌سازی هشدارها و مجوزها',
                        subtitle: 'مجوزهای لازم را صادر کرده و هشدارها را فعال کنید',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const MtSectionTitle(
                  title: 'دسترسی‌های مورد نیاز',
                  subtitle: 'برای عملکرد بهتر سامانه، دسترسی‌های زیر را فعال کنید.',
                ),
                const SizedBox(height: 12),
                MtCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: const [
                      _PermissionRow(
                        icon: Icons.notifications_none_rounded,
                        title: 'اعلان‌ها',
                        subtitle: 'دریافت هشدارها و اطلاع‌رسانی‌های مهم',
                      ),
                      MtDivider(),
                      _PermissionRow(
                        icon: Icons.phone_outlined,
                        title: 'تماس',
                        subtitle: 'برای تماس با سیم‌کارت ردیاب در قابلیت شنود',
                      ),
                      MtDivider(),
                      _PermissionRow(
                        icon: Icons.sms_outlined,
                        title: 'پیامک (اختیاری)',
                        subtitle: 'فقط در صورت فعال‌کردن SMS Backup ردیاب',
                        initialEnabled: false,
                      ),
                      MtDivider(),
                      _PermissionRow(
                        icon: Icons.location_on_outlined,
                        title: 'موقعیت مکانی',
                        subtitle: 'برای امکانات نقشه و مسیریابی روی گوشی',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                MtRedButton(
                  label: 'شروع راه‌اندازی',
                  icon: Icons.arrow_back_rounded,
                  onPressed: onStart,
                  height: 58,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onLogin,
                  child: const Text(
                    'قبلاً حساب دارم',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String subtitle;

  const _SetupStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MtColors.red.withOpacity(.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: MtColors.red, size: 27),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
          Container(
            width: 43,
            height: 43,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: MtColors.red.withOpacity(.18)),
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: MtColors.red,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool initialEnabled;

  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.initialEnabled = true,
  });

  @override
  State<_PermissionRow> createState() => _PermissionRowState();
}

class _PermissionRowState extends State<_PermissionRow> {
  late bool enabled;

  @override
  void initState() {
    super.initState();
    enabled = widget.initialEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(.06),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(widget.icon, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  widget.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeColor: Colors.white,
            activeTrackColor: MtColors.red,
            onChanged: (v) => setState(() => enabled = v),
          ),
        ],
      ),
    );
  }
}
