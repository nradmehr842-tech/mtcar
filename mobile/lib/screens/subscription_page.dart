import 'package:flutter/material.dart';
import '../app/mtcar_theme.dart';
import '../services/account_api.dart';
import '../widgets/mtcar_design.dart';

class SubscriptionPage extends StatefulWidget {
  final String baseUrl;
  final String token;
  final bool darkMode;
  final VoidCallback onTheme;

  const SubscriptionPage({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.darkMode,
    required this.onTheme,
  });

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  late final AccountApi api;
  Map<String, dynamic>? status;
  Map<String, dynamic>? plan;
  List<dynamic>? payments;
  bool loading = true;
  bool paying = false;

  @override
  void initState() {
    super.initState();
    api = AccountApi(widget.baseUrl, token: widget.token);
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        api.subscriptionStatus(),
        api.plan(),
        api.paymentHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        status = Map<String, dynamic>.from(results[0] as Map);
        plan = Map<String, dynamic>.from(results[1] as Map);
        payments = List<dynamic>.from(results[2] as List);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        payments = const [];
        loading = false;
      });
    }
  }

  String _price(dynamic value) {
    if (value == null) return 'از سرور دریافت می‌شود';
    final n = int.tryParse(value.toString());
    if (n == null) return value.toString();
    final s = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return '${out.toString()} تومان';
  }

  Future<void> _checkout() async {
    if (paying) return;
    setState(() => paying = true);
    try {
      final result = await api.checkoutAnnual();
      if (!mounted) return;
      final url = result['paymentUrl'] ?? result['url'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            url == null
                ? 'درگاه پرداخت هنوز روی سرور تنظیم نشده است.'
                : 'لینک پرداخت توسط سرور ایجاد شد. اتصال Browser/Deep-link در مرحله Deploy فعال می‌شود.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اتصال به درگاه پرداخت انجام نشد.')),
        );
      }
    } finally {
      if (mounted) setState(() => paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = status?['subscription'] is Map
        ? Map<String, dynamic>.from(status!['subscription'] as Map)
        : <String, dynamic>{};
    final active = status?['active'] == true;
    final endsRaw = subscription['ends_at'] ?? subscription['endsAt'];
    final endsDate = endsRaw == null ? null : DateTime.tryParse(endsRaw.toString());
    final days = endsDate == null
        ? '—'
        : (endsDate.difference(DateTime.now()).inHours / 24).ceil().clamp(0, 99999);
    final endsAt = endsRaw ?? '—';
    final annualPrice = plan?['priceToman'] ?? status?['priceToman'] ?? plan?['annualPriceToman'] ?? plan?['price'];

    return Scaffold(
      body: Column(
        children: [
          MtPremiumHeader(
            onTheme: widget.onTheme,
            darkMode: widget.darkMode,
            showBack: true,
            notificationCount: 0,
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                    children: [
                      const MtSectionTitle(
                        title: 'اشتراک و پرداخت',
                        subtitle: 'مدیریت اشتراک، پرداخت‌ها و تاریخچه تراکنش‌ها',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      const SizedBox(height: 16),
                      MtCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const MtSectionTitle(
                              title: 'اشتراک فعلی شما',
                              icon: Icons.shield_outlined,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              textDirection: TextDirection.ltr,
                              children: [
                                Container(
                                  width: 130,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF2533), Color(0xFFB60008)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: Colors.white, width: 4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: MtColors.red.withOpacity(.25),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 48),
                                      SizedBox(height: 8),
                                      Text('PREMIUM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                                      SizedBox(height: 5),
                                      Text('★ ★ ★ ★ ★', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'اشتراک سالانه',
                                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                          MtStatusPill(
                                            text: active ? 'فعال' : 'منقضی',
                                            color: active ? Colors.green : MtColors.red,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _InfoLine(icon: Icons.schedule_rounded, label: 'روزهای باقی‌مانده', value: '$days روز', accent: active),
                                      const MtDivider(),
                                      _InfoLine(icon: Icons.calendar_month_outlined, label: 'تاریخ انقضاء', value: '$endsAt'),
                                      const MtDivider(),
                                      _InfoLine(icon: Icons.sell_outlined, label: 'قیمت سالانه', value: _price(annualPrice)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            MtRedButton(
                              label: paying ? 'در حال اتصال...' : 'تمدید اشتراک',
                              icon: Icons.workspace_premium_rounded,
                              onPressed: paying ? null : _checkout,
                              height: 58,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      MtCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const MtSectionTitle(
                              title: 'اشتراک سازمانی و کسب‌وکار',
                              subtitle: 'مدیریت ناوگان، کاربران سازمانی و راهکارهای ویژه کسب‌وکارها',
                              icon: Icons.apartment_rounded,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'برای خرید سازمانی و مدیریت چند خودرو، درخواست سازمانی ثبت کنید. قیمت سازمانی و شرایط قرارداد از سرور/پنل مدیریت تعیین می‌شود.',
                              style: TextStyle(height: 1.55),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: MtRedButton(
                                    label: 'اطلاعات بیشتر',
                                    outlined: true,
                                    onPressed: () {},
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: MtRedButton(
                                    label: 'ثبت درخواست سازمانی',
                                    icon: Icons.apartment_rounded,
                                    onPressed: () {},
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      MtCard(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const MtSectionTitle(
                              title: 'تاریخچه پرداخت‌ها',
                              subtitle: 'آخرین پرداخت‌ها و وضعیت تراکنش‌ها',
                              icon: Icons.sync_rounded,
                            ),
                            const SizedBox(height: 12),
                            if (payments == null || payments!.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(18),
                                child: Text(
                                  'هنوز پرداختی ثبت نشده است.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            else
                              ...payments!.take(5).map((p) => _PaymentRow(data: Map<String, dynamic>.from(p as Map))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(.045),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 19),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'قیمت‌ها و اطلاعیه‌ها به‌صورت آنلاین از سرور دریافت می‌شوند و داخل APK ثابت نیستند.',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey),
                              ),
                            ),
                          ],
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

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool accent;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 21),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: accent ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final Map<String, dynamic> data;

  const _PaymentRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final ok = data['status'] == 'verified' || data['status'] == 'success' || data['status'] == 'paid';
    final ref = data['tracking_code'] ?? data['reference'] ?? data['provider_reference'] ?? '—';
    final date = data['created_at'] ?? data['verified_at'] ?? '—';
    final amount = data['amount_toman'] ?? data['amount'] ?? '—';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(.10))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: MtStatusPill(
              text: ok ? 'موفق' : '${data['status'] ?? 'نامشخص'}',
              color: ok ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('$ref', style: const TextStyle(fontSize: 11.5))),
          Expanded(child: Text('$date', style: const TextStyle(fontSize: 11.5))),
          Expanded(child: Text('$amount', textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
        ],
      ),
    );
  }
}
