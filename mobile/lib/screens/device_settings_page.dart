import 'package:flutter/material.dart';
import '../app/mtcar_theme.dart';
import '../services/device_models_api.dart';
import '../services/sim_api.dart';
import '../widgets/mtcar_design.dart';

class DeviceSettingsPage extends StatefulWidget {
  final String baseUrl;
  final String token;
  final int? deviceId;
  final bool deviceOnline;
  final bool darkMode;
  final VoidCallback onTheme;

  const DeviceSettingsPage({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.deviceId,
    required this.deviceOnline,
    required this.darkMode,
    required this.onTheme,
  });

  @override
  State<DeviceSettingsPage> createState() => _DeviceSettingsPageState();
}

class _DeviceSettingsPageState extends State<DeviceSettingsPage> {
  Map<String, dynamic>? profile;
  Map<String, dynamic>? simStatus;
  bool loading = true;
  bool refreshing = false;
  String? error;

  late final DeviceModelsApi modelsApi;
  late final SimApi simApi;

  @override
  void initState() {
    super.initState();
    modelsApi = DeviceModelsApi(widget.baseUrl, widget.token);
    simApi = SimApi(widget.baseUrl, widget.token);
    _load();
  }

  Future<void> _load() async {
    final id = widget.deviceId;
    if (id == null) {
      setState(() {
        loading = false;
        error = 'هنوز دستگاهی به حساب اضافه نشده است.';
      });
      return;
    }

    try {
      final results = await Future.wait([
        modelsApi.profile(id),
        simApi.status(id).catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        profile = Map<String, dynamic>.from(results[0] as Map);
        simStatus = Map<String, dynamic>.from(results[1] as Map);
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'دریافت اطلاعات دستگاه انجام نشد.';
      });
    }
  }

  Future<void> _refreshSim() async {
    final id = widget.deviceId;
    if (id == null || refreshing) return;
    setState(() => refreshing = true);
    try {
      final data = await simApi.refresh(id);
      if (!mounted) return;
      setState(() => simStatus = data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('درخواست استعلام مجدد ارسال شد.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('استعلام سیم‌کارت انجام نشد.')),
      );
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  String _safe(dynamic value, [String fallback = 'در دسترس نیست']) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.deviceOnline;
    final simActive = simStatus?['simActive'] == true;
    final model = _safe(profile?['display_name'] ?? profile?['model'], 'MT120');
    final imei = _safe(profile?['imei']);
    final simPhone = _safe(profile?['tracker_sim_phone'] ?? simStatus?['phone']);
    final operatorName = _safe(simStatus?['operatorName'] ?? profile?['tracker_sim_operator'] ?? simStatus?['operator']);
    final airtime = simStatus?['airtime'] is Map
        ? Map<String, dynamic>.from(simStatus!['airtime'] as Map)
        : <String, dynamic>{};
    final data = simStatus?['data'] is Map
        ? Map<String, dynamic>.from(simStatus!['data'] as Map)
        : <String, dynamic>{};
    final balance = airtime['available'] == true && airtime['balanceRial'] != null
        ? '${airtime['balanceRial']} ریال'
        : 'در دسترس نیست';
    final internet = data['available'] == true && data['remainingMb'] != null
        ? '${data['remainingMb']} MB'
        : 'در دسترس نیست';
    final refreshed = _safe(simStatus?['lastQueriedAt']);

    return Scaffold(
      body: Column(
        children: [
          MtPremiumHeader(
            onTheme: widget.onTheme,
            darkMode: widget.darkMode,
            notificationCount: 0,
            showBack: true,
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 31),
                          ),
                          const Expanded(
                            child: Text(
                              'تنظیمات دستگاه',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        MtCard(
                          child: Text(error!, style: const TextStyle(color: MtColors.red)),
                        ),
                      ],
                      const SizedBox(height: 16),
                      MtCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _SettingRow(
                              icon: Icons.watch_outlined,
                              title: 'نوع دستگاه:',
                              value: model,
                            ),
                            const MtDivider(),
                            _SettingRow(
                              icon: Icons.memory_rounded,
                              title: 'IMEI دستگاه',
                              value: imei,
                            ),
                            const MtDivider(),
                            _SettingRow(
                              icon: Icons.sim_card_outlined,
                              title: 'شماره سیم‌کارت دستگاه',
                              value: simPhone,
                            ),
                            const MtDivider(),
                            _SettingRow(
                              icon: Icons.signal_cellular_alt_rounded,
                              title: 'اپراتور سیم‌کارت',
                              value: operatorName,
                            ),
                            const MtDivider(),
                            _SettingRow(
                              icon: Icons.shield_outlined,
                              title: 'وضعیت دستگاه',
                              value: online ? 'آنلاین' : 'در دسترس نیست',
                              good: online,
                            ),
                            const MtDivider(),
                            _SettingRow(
                              icon: Icons.fact_check_outlined,
                              title: 'وضعیت سیم‌کارت',
                              value: simActive ? 'فعال' : 'در دسترس نیست',
                              good: simActive,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      MtCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                              child: Text(
                                'وضعیت سیم‌کارت',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                              ),
                            ),
                            _SettingRow(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'شارژ اصلی',
                              value: balance,
                            ),
                            const MtDivider(),
                            _SettingRow(
                              icon: Icons.public_rounded,
                              title: 'اینترنت باقی‌مانده',
                              value: internet,
                            ),
                            const MtDivider(),
                            _SettingRow(
                              icon: Icons.schedule_rounded,
                              title: 'آخرین استعلام',
                              value: refreshed,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                              child: Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(.045),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.withOpacity(.12)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'مقادیر فقط بر اساس آخرین پاسخ معتبر اپراتور نمایش داده می‌شوند. اگر Provider مقدار واقعی ندهد، «در دسترس نیست» نمایش داده می‌شود.',
                                        style: TextStyle(fontSize: 11.5, height: 1.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: MtRedButton(
                              label: refreshing ? 'در حال استعلام...' : 'استعلام مجدد',
                              icon: Icons.refresh_rounded,
                              onPressed: refreshing ? null : _refreshSim,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MtRedButton(
                              label: 'سوابق خرید',
                              icon: Icons.history_rounded,
                              outlined: true,
                              onPressed: widget.deviceId == null
                                  ? null
                                  : () => _showPurchases(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: MtRedButton(
                              label: 'شارژ سیم‌کارت',
                              icon: Icons.account_balance_wallet_outlined,
                              outlined: true,
                              onPressed: widget.deviceId == null ? null : () => _showTopup(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MtRedButton(
                              label: 'خرید بسته اینترنت',
                              icon: Icons.language_rounded,
                              outlined: true,
                              onPressed: widget.deviceId == null
                                  ? null
                                  : () => _showInternetPackages(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPurchases(BuildContext context) async {
    final id = widget.deviceId!;
    try {
      final rows = await simApi.purchases(id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('سوابق خرید سیم‌کارت', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Text('سابقه‌ای ثبت نشده است.')
              else
                ...rows.map((x) => Card(
                      child: ListTile(
                        title: Text(_safe(x['type'] ?? x['package_name'], 'خرید')), 
                        subtitle: Text(_safe(x['created_at'] ?? x['createdAt'], '—')),
                        trailing: Text(_safe(x['status'], '—')),
                      ),
                    )),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سوابق خرید در دسترس نیست.')));
    }
  }

  Future<void> _showTopup(BuildContext context) async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('شارژ سیم‌کارت'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'مبلغ به ریال'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('ادامه'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0) return;
    try {
      await simApi.topup(deviceId: widget.deviceId!, amountRial: amount);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('درخواست شارژ ثبت شد.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سرویس شارژ فعلاً در دسترس نیست.')));
    }
  }

  Future<void> _showInternetPackages(BuildContext context) async {
    try {
      final data = await simApi.internetPackages(widget.deviceId!);
      final packages = data['packages'] is List ? List<dynamic>.from(data['packages']) : const [];
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('بسته‌های اینترنت', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              if (packages.isEmpty)
                const Text('در حال حاضر بسته‌ای از Provider دریافت نشده است.')
              else
                ...packages.map((x) => Card(
                      child: ListTile(
                        title: Text(_safe(x['name'], 'بسته اینترنت')),
                        subtitle: Text(_safe(x['description'] ?? x['price'], '—')),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () async {
                          Navigator.pop(context);
                          try {
                            await simApi.buyInternetPackage(
                              deviceId: widget.deviceId!,
                              packageId: _safe(x['id'], ''),
                              packageName: _safe(x['name'], 'بسته اینترنت'),
                            );
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('درخواست خرید بسته ثبت شد.')));
                          } catch (_) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خرید بسته انجام نشد.')));
                          }
                        },
                      ),
                    )),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فهرست بسته‌ها در دسترس نیست.')));
    }
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool good;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.value,
    this.good = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 11),
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (good) ...[
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: good ? Colors.green : null,
                fontWeight: good ? FontWeight.w800 : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
