import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app/mtcar_theme.dart';
import '../services/account_api.dart';
import '../services/alert_bridge.dart';
import '../services/api.dart';
import '../services/bootstrap_api.dart';
import '../services/device_models_api.dart';
import '../services/events_api.dart';
import '../services/support_api.dart';
import '../widgets/mtcar_design.dart';
import 'add_device_sheet.dart';
import 'device_settings_page.dart';
import 'map_settings_page.dart';
import 'route_replay_page.dart';
import 'subscription_page.dart';

class MainShell extends StatefulWidget {
  final String baseUrl;
  final String token;
  final bool darkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;

  const MainShell({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.darkMode,
    required this.onToggleTheme,
    required this.onLogout,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  bool loading = true;
  bool protection = true;
  AppBootstrap? bootstrap;
  Map<String, dynamic>? position;
  Map<String, dynamic>? deviceProfile;
  List<dynamic> events = [];
  String? loadError;

  late final BootstrapApi bootstrapApi;
  late final FleetApi fleetApi;
  late final EventsApi eventsApi;
  late final DeviceModelsApi deviceModelsApi;

  @override
  void initState() {
    super.initState();
    bootstrapApi = BootstrapApi(widget.baseUrl, widget.token);
    fleetApi = FleetApi(widget.baseUrl, widget.token);
    eventsApi = EventsApi(widget.baseUrl, widget.token);
    deviceModelsApi = DeviceModelsApi(widget.baseUrl, widget.token);
    _load();
  }

  Map<String, dynamic>? get activeDevice {
    final devices = bootstrap?.devices ?? const [];
    if (devices.isEmpty) return null;
    return Map<String, dynamic>.from(devices.first as Map);
  }

  int? get deviceId {
    final raw = activeDevice?['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  String get vehicleName {
    final value = activeDevice?['vehicle_name']?.toString().trim();
    return value?.isNotEmpty == true ? value! : 'خودروی من';
  }

  bool get offlineMode => widget.token == 'mtcar_local_offline_session';

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }

    if (offlineMode) {
      if (!mounted) return;
      setState(() {
        bootstrap = AppBootstrap(
          serverTime: DateTime.now(),
          user: const <String, dynamic>{'username': 'mtcar', 'offline': true},
          subscription: const <String, dynamic>{
            'active': false,
            'expired': false,
            'offline': true,
            'daysRemaining': 0,
          },
          devices: const <dynamic>[],
          config: const <String, dynamic>{},
        );
        position = null;
        deviceProfile = null;
        events = const <dynamic>[];
        loadError = 'حالت آفلاین فعال است؛ اطلاعات زنده پس از اتصال به سرور نمایش داده می‌شود.';
        loading = false;
      });
      return;
    }

    try {
      final data = await bootstrapApi.load();
      Map<String, dynamic>? pos;
      Map<String, dynamic>? profile;
      List<dynamic> ev = [];

      if (data.devices.isNotEmpty) {
        final d = Map<String, dynamic>.from(data.devices.first as Map);
        final raw = d['id'];
        final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
        if (id != null) {
          // Device profile remains available even when cloud subscription is expired,
          // so local SMS Backup / monitor capabilities can still be represented safely.
          try {
            profile = await deviceModelsApi.profile(id);
          } catch (_) {
            profile = null;
          }

          if (data.subscription['active'] == true) {
            try {
              pos = await fleetApi.position(id);
            } catch (_) {
              pos = null;
            }
            try {
              ev = await eventsApi.events(id, limit: 30);
            } catch (_) {
              ev = [];
            }
          }
        }
      }

      try {
        final local = await AlertBridge.getLocalEvents();
        final normalized = local.map((raw) {
          final m = Map<String, dynamic>.from(raw as Map);
          final type = m['type']?.toString() ?? 'sms';
          final severe = const ['tamper','power','sos','lowbattery'].contains(type)
              ? 'critical'
              : const ['shock','movement','door','acc'].contains(type)
                  ? 'warning'
                  : 'info';
          final ms = m['time'] is num ? (m['time'] as num).toInt() : null;
          return <String, dynamic>{
            'event_type': type,
            'severity': severe,
            'title': m['title'] ?? 'هشدار محلی',
            'message': m['body'],
            'source': 'android_sms_backup',
            'event_time': ms == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String(),
          };
        }).toList();
        ev = [...normalized, ...ev];
      } catch (_) {
        // Local SMS event history is Android-only and optional.
      }

      if (!mounted) return;
      setState(() {
        bootstrap = data;
        position = pos;
        deviceProfile = profile;
        events = ev;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadError = 'ارتباط با سرور برقرار نیست.';
        loading = false;
      });
    }
  }

  Future<void> _addDevice() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddDeviceSheet(
        baseUrl: widget.baseUrl,
        token: widget.token,
        onCreated: _load,
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleProtection() async {
    if (activeDevice == null) {
      _snack('ابتدا ردیاب MT120 را به حساب اضافه کنید.');
      return;
    }
    try {
      if (protection) {
        await AlertBridge.disarmVehicle();
      } else {
        await AlertBridge.armVehicle();
      }
      if (!mounted) return;
      setState(() => protection = !protection);
      _snack(protection ? 'محافظت فعال شد.' : 'محافظت غیرفعال شد.');
    } catch (_) {
      if (mounted) _snack('ارسال فرمان محافظت انجام نشد. تنظیمات SMS را بررسی کنید.');
    }
  }

  Future<void> _voiceMonitor() async {
    if (activeDevice == null) {
      _snack('ابتدا دستگاه را اضافه کنید.');
      return;
    }

    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('شنود آنلاین'),
        content: const Text(
          'فقط برای خودرویی ادامه دهید که اختیار و مجوز قانونی استفاده از میکروفون آن را دارید. '
          'MTcar صدا را ضبط نمی‌کند. در Monitor Mode ممکن است رهگیری GPS موقتاً متوقف شود؛ پس از پایان تماس باید Tracker Mode بازیابی شود.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ادامه')),
        ],
      ),
    );
    if (allowed != true) return;

    try {
      await AlertBridge.enableVoiceMonitor();
      await AlertBridge.openTrackerDialer();
    } catch (_) {
      if (mounted) _snack('شنود فعال نشد. شماره سیم‌کارت و مجوز SMS را بررسی کنید.');
    }
  }

  Future<void> _engineStop() async {
    final id = deviceId;
    if (id == null) {
      _snack('ابتدا دستگاه را آنلاین کنید.');
      return;
    }

    final speedKnots = (position?['speed'] as num?)?.toDouble() ?? 0;
    final speedKmh = speedKnots * 1.852;
    if (speedKmh > 20) {
      _snack('برای ایمنی، قطع موتور در سرعت بالاتر از ۲۰ km/h مجاز نیست.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قطع موتور'),
        content: const Text(
          'این فرمان فقط با گیت ایمنی سرور ارسال می‌شود. نصب رله باید توسط نصاب متخصص انجام شده باشد.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ارسال فرمان')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await fleetApi.engineStop(id);
      if (mounted) _snack('فرمان قطع موتور ارسال شد.');
    } catch (_) {
      if (mounted) _snack('فرمان قطع موتور ارسال نشد یا گیت ایمنی آن را رد کرد.');
    }
  }

  Future<void> _engineResume() async {
    final id = deviceId;
    if (id == null) return;
    try {
      await fleetApi.engineResume(id);
      if (mounted) _snack('فرمان وصل مجدد موتور ارسال شد.');
    } catch (_) {
      if (mounted) _snack('ارسال فرمان وصل موتور انجام نشد.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = bootstrap?.subscription ?? const <String, dynamic>{};
    final expired = sub['expired'] == true;
    final alertCount = events.where((e) {
      final s = e is Map ? e['severity']?.toString() : null;
      return s == 'critical' || s == 'warning';
    }).length;

    final pages = <Widget>[
      _HomeTab(
        baseUrl: widget.baseUrl,
        token: widget.token,
        darkMode: widget.darkMode,
        loading: loading,
        loadError: loadError,
        device: activeDevice,
        deviceProfile: deviceProfile,
        position: position,
        events: events,
        protection: protection,
        subscription: sub,
        onRefresh: _load,
        onAddDevice: _addDevice,
        onFind: () => setState(() => tab = 1),
        onAlerts: () => setState(() => tab = 2),
        onProtection: _toggleProtection,
        onVoice: _voiceMonitor,
        onSiren: () => _snack('فرمان آژیر فقط پس از تایید Command Profile واقعی MT120 فعال می‌شود.'),
        onEngineStop: _engineStop,
      ),
      _MapTab(
        baseUrl: widget.baseUrl,
        token: widget.token,
        darkMode: widget.darkMode,
        deviceId: deviceId,
        vehicleName: vehicleName,
        position: position,
        onTheme: widget.onToggleTheme,
        onRefresh: _load,
      ),
      _AlertsTab(
        events: events,
        hasDevice: activeDevice != null,
        capabilities: deviceProfile?['capabilities'] is Map
            ? Map<String, dynamic>.from(deviceProfile!['capabilities'] as Map)
            : const <String, dynamic>{},
        protection: protection,
        onProtection: _toggleProtection,
        onVoice: _voiceMonitor,
        onFind: () => setState(() => tab = 1),
        onSiren: () => _snack('فرمان آژیر پس از تایید Firmware/Command Profile فعال می‌شود.'),
        onEngineStop: _engineStop,
        onEngineResume: _engineResume,
      ),
      _SupportTab(baseUrl: widget.baseUrl, token: widget.token),
      _AccountTab(
        baseUrl: widget.baseUrl,
        token: widget.token,
        darkMode: widget.darkMode,
        bootstrap: bootstrap,
        deviceId: deviceId,
        deviceOnline: position != null,
        onTheme: widget.onToggleTheme,
        onLogout: widget.onLogout,
        onAddDevice: _addDevice,
      ),
    ];

    return Scaffold(
      body: Column(
        children: [
          MtPremiumHeader(
            onTheme: widget.onToggleTheme,
            darkMode: widget.darkMode,
            notificationCount: alertCount,
            onBell: () => setState(() => tab = 2),
          ),
          if (expired)
            _ExpiryBanner(
              text: sub['renewalMessage']?.toString() ??
                  'دوره اعتبار حساب شما به پایان رسیده است. برای شارژ به پنل حساب کاربری خود مراجعه کنید.',
              onRenew: () => setState(() => tab = 4),
            ),
          Expanded(
            child: IndexedStack(index: tab, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: MtBottomNav(
        index: tab,
        alertCount: alertCount,
        onChanged: (value) => setState(() => tab = value),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final String baseUrl;
  final String token;
  final bool darkMode;
  final bool loading;
  final String? loadError;
  final Map<String, dynamic>? device;
  final Map<String, dynamic>? deviceProfile;
  final Map<String, dynamic>? position;
  final List<dynamic> events;
  final bool protection;
  final Map<String, dynamic> subscription;
  final VoidCallback onRefresh;
  final VoidCallback onAddDevice;
  final VoidCallback onFind;
  final VoidCallback onAlerts;
  final VoidCallback onProtection;
  final VoidCallback onVoice;
  final VoidCallback onSiren;
  final VoidCallback onEngineStop;

  const _HomeTab({
    required this.baseUrl,
    required this.token,
    required this.darkMode,
    required this.loading,
    required this.loadError,
    required this.device,
    required this.deviceProfile,
    required this.position,
    required this.events,
    required this.protection,
    required this.subscription,
    required this.onRefresh,
    required this.onAddDevice,
    required this.onFind,
    required this.onAlerts,
    required this.onProtection,
    required this.onVoice,
    required this.onSiren,
    required this.onEngineStop,
  });

  @override
  Widget build(BuildContext context) {
    final online = position != null;
    final speed = (position?['speed'] as num?)?.toDouble();
    final kmh = speed == null ? null : speed * 1.852;
    final attrs = position?['attributes'] is Map
        ? Map<String, dynamic>.from(position!['attributes'] as Map)
        : <String, dynamic>{};
    final capabilities = deviceProfile?['capabilities'] is Map
        ? Map<String, dynamic>.from(deviceProfile!['capabilities'] as Map)
        : <String, dynamic>{};
    bool cap(String key, {bool fallback = false}) =>
        capabilities.containsKey(key) ? capabilities[key] == true : fallback;
    final isMotorcycle = device?['vehicle_type']?.toString() == 'motorcycle';
    final voltage = attrs['power'] ?? attrs['batteryVoltage'] ?? attrs['voltage'];
    final battery = attrs['batteryLevel'] ?? attrs['battery'];
    final ignition = attrs['ignition'];
    final gsm = attrs['rssi'] ?? attrs['signal'];
    final fuel = attrs['fuel'] ?? attrs['fuelLevel'];
    final rpm = attrs['rpm'];
    final temp = attrs['coolantTemp'] ?? attrs['temperature'];
    final address = position?['address']?.toString();
    final vehicle = device?['vehicle_name']?.toString().trim();
    final vehicleName = vehicle?.isNotEmpty == true ? vehicle! : 'خودروی من';

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        children: [
          if (loading) const LinearProgressIndicator(),
          if (loadError != null) ...[
            MtCard(
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: MtColors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(loadError!)),
                  TextButton(onPressed: onRefresh, child: const Text('تلاش مجدد')),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          MtCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.directions_car_filled_outlined),
                const SizedBox(width: 8),
                const Text('خودروی من', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(width: 7),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: MtColors.red, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text('وضعیت زنده خودرو', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                ),
                const Icon(Icons.language_rounded, size: 20),
                const SizedBox(width: 6),
                const Text('FA  |  EN', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          MtCard(
            child: Column(
              children: [
                Row(
                  textDirection: TextDirection.ltr,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  vehicleName,
                                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(width: 8),
                              MtStatusPill(
                                text: online ? 'آنلاین' : 'آفلاین',
                                color: online ? Colors.green : Colors.grey,
                              ),
                            ],
                          ),
                          const SizedBox(height: 13),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 20),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  address?.isNotEmpty == true
                                      ? address!
                                      : device == null
                                          ? 'هنوز ردیابی به حساب اضافه نشده است.'
                                          : 'در انتظار دریافت موقعیت واقعی از دستگاه',
                                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text('آخرین بروزرسانی: ', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                              Text(
                                position?['serverTime']?.toString() ?? '—',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.refresh_rounded, color: MtColors.red, size: 17),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      height: 170,
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Image.asset(
                              darkMode
                                  ? 'assets/images/mtcar_vehicle.png'
                                  : 'assets/images/mtcar_vehicle_red.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const Positioned(
                            right: 14,
                            top: 0,
                            child: Icon(Icons.location_on_rounded, color: MtColors.red, size: 50),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (device == null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: MtRedButton(
                      label: 'افزودن MT120',
                      icon: Icons.add_circle_outline_rounded,
                      onPressed: onAddDevice,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    Expanded(
                      child: _MiniStatus(
                        icon: isMotorcycle ? Icons.two_wheeler_rounded : Icons.lock_outline_rounded,
                        label: isMotorcycle ? 'حرکت / ضربه' : 'درب‌ها',
                        value: isMotorcycle
                            ? (attrs['motion'] == true || attrs['alarm'] == 'shock' ? 'هشدار' : '—')
                            : (cap('door')
                                ? (attrs['door'] == true ? 'باز' : attrs.containsKey('door') ? 'بسته' : '—')
                                : 'پشتیبانی نمی‌شود'),
                        color: MtColors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatus(
                        icon: Icons.signal_cellular_alt_rounded,
                        label: 'شبکه GSM',
                        value: gsm == null ? (online ? 'متصل' : '—') : '$gsm',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatus(
                        icon: Icons.battery_5_bar_rounded,
                        label: 'باتری',
                        value: voltage != null ? '$voltage V' : battery != null ? '$battery%' : '—',
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatus(
                        icon: Icons.speed_rounded,
                        label: 'ACC',
                        value: ignition == true ? 'روشن' : ignition == false ? 'خاموش' : '—',
                        color: ignition == true ? Colors.green : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('دسترسی سریع', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: .78,
              children: [
                _QuickAction(icon: Icons.my_location_rounded, label: 'یافتن خودرو', color: MtColors.red, onTap: onFind),
                _QuickAction(icon: Icons.headphones_rounded, label: 'شنود آنلاین', onTap: device == null || !cap('voiceMonitor') ? null : onVoice),
                _QuickAction(icon: Icons.campaign_rounded, label: 'آژیر خودرو', selected: true, onTap: device == null || !cap('siren') ? null : onSiren),
                _QuickAction(icon: Icons.shield_outlined, label: 'محافظت', selected: protection, onTap: device == null ? null : onProtection),
                _QuickAction(icon: Icons.power_settings_new_rounded, label: 'قطع موتور', color: MtColors.red, onTap: device == null || !cap('engineControl') ? null : onEngineStop),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MtCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('وضعیت زنده خودرو', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    Expanded(child: _Telemetry(icon: Icons.speed_rounded, value: kmh == null ? '—' : kmh.toStringAsFixed(0), unit: 'km/h', label: 'سرعت')),
                    Expanded(child: _Telemetry(icon: Icons.speed_rounded, value: rpm == null ? '—' : '$rpm', unit: rpm == null ? '' : 'RPM', label: 'دور موتور', unavailableNote: rpm == null)),
                    Expanded(child: _Telemetry(icon: Icons.thermostat_rounded, value: temp == null ? '—' : '$temp°', unit: '', label: 'دمای موتور', unavailableNote: temp == null)),
                    Expanded(child: _Telemetry(icon: Icons.local_gas_station_outlined, value: !cap('fuelSensor') || fuel == null ? '—' : '$fuel%', unit: '', label: 'سطح سوخت', unavailableNote: !cap('fuelSensor') || fuel == null)),
                    Expanded(child: _Telemetry(icon: Icons.battery_charging_full_rounded, value: voltage == null ? '—' : '$voltage V', unit: '', label: 'ولتاژ باتری')),
                  ],
                ),
                if (rpm == null || temp == null || fuel == null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'RPM، دمای موتور و سوخت فقط وقتی نمایش داده می‌شوند که سنسور/OBD واقعی آن داده را به سرور ارسال کند؛ MTcar مقدار ساختگی نشان نمی‌دهد.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          MtCard(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('هشدارها و فعالیت‌های اخیر', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    ),
                    TextButton(onPressed: onAlerts, child: const Text('مشاهده همه')),
                  ],
                ),
                if (events.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'رویداد واقعی ثبت‌شده‌ای وجود ندارد.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ...events.take(3).map((e) => _EventRow(event: Map<String, dynamic>.from(e as Map))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SubscriptionStrip(subscription: subscription),
        ],
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _MiniStatus({required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(.025)
            : const Color(0xFFFCFCFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(.12)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 5),
              Flexible(child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 11, color: color ?? Colors.grey, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback? onTap;

  const _QuickAction({required this.icon, required this.label, this.selected = false, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = selected;
    return Material(
      color: active ? MtColors.red : (Theme.of(context).cardTheme.color ?? Colors.white),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? Colors.white.withOpacity(.5) : Colors.grey.withOpacity(.12)),
            boxShadow: active
                ? [BoxShadow(color: MtColors.red.withOpacity(.35), blurRadius: 16, offset: const Offset(0, 7))]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 27, color: active ? Colors.white : (color ?? Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.3,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : (onTap == null ? Colors.grey : null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Telemetry extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final bool unavailableNote;

  const _Telemetry({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    this.unavailableNote = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: MtColors.red, size: 27),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        if (unit.isNotEmpty) Text(unit, style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        if (unavailableNote)
          const Text('سنسور ندارد', style: TextStyle(fontSize: 8.5, color: Colors.grey)),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  final Map<String, dynamic> event;

  const _EventRow({required this.event});

  Color get color {
    switch (event['severity']) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'success':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(.10))),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.notifications_active_outlined, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${event['title'] ?? event['event_type'] ?? 'رویداد'}', style: const TextStyle(fontWeight: FontWeight.w800))),
                  ],
                ),
                if (event['message'] != null) ...[
                  const SizedBox(height: 3),
                  Text('${event['message']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ],
            ),
          ),
          Text('${event['event_time'] ?? ''}', style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MapTab extends StatelessWidget {
  final String baseUrl;
  final String token;
  final bool darkMode;
  final int? deviceId;
  final String vehicleName;
  final Map<String, dynamic>? position;
  final VoidCallback onTheme;
  final VoidCallback onRefresh;

  const _MapTab({
    required this.baseUrl,
    required this.token,
    required this.darkMode,
    required this.deviceId,
    required this.vehicleName,
    required this.position,
    required this.onTheme,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final lat = (position?['latitude'] as num?)?.toDouble();
    final lon = (position?['longitude'] as num?)?.toDouble();
    final hasLocation = lat != null && lon != null;
    final center = hasLocation ? LatLng(lat, lon) : const LatLng(35.7219, 51.3347);
    final speed = (position?['speed'] as num?)?.toDouble();
    final attrs = position?['attributes'] is Map
        ? Map<String, dynamic>.from(position!['attributes'] as Map)
        : <String, dynamic>{};
    final voltage = attrs['power'] ?? attrs['batteryVoltage'] ?? attrs['voltage'];
    final ignition = attrs['ignition'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        MtCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.directions_car_filled_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(vehicleName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              ),
              MtStatusPill(text: hasLocation ? 'آنلاین' : 'بدون موقعیت', color: hasLocation ? Colors.green : Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 570,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: hasLocation ? 16 : 11),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'ir.mediatelecom.mtcar',
                    ),
                    if (hasLocation)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: center,
                            width: 82,
                            height: 82,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.green.withOpacity(.5), width: 4),
                                boxShadow: [BoxShadow(color: Colors.green.withOpacity(.25), blurRadius: 18)],
                              ),
                              child: const Icon(Icons.directions_car_filled_rounded, color: Colors.black87, size: 33),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  left: 16,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MapAction(label: 'مرکز روی خودرو', icon: Icons.my_location_rounded, onTap: onRefresh),
                      const SizedBox(height: 8),
                      _MapAction(
                        label: 'نمایش همه',
                        icon: Icons.layers_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(body: SafeArea(child: MapSettingsPage(baseUrl: baseUrl, token: token))),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _MapAction(
                        label: 'تاریخچه مسیر',
                        icon: Icons.history_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RouteReplayPage(
                                baseUrl: baseUrl,
                                token: token,
                                deviceId: deviceId,
                                darkMode: darkMode,
                                onTheme: onTheme,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        MtCard(
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              Expanded(child: _MapMetric(icon: Icons.battery_charging_full_rounded, label: 'ولتاژ باتری', value: voltage == null ? '—' : '$voltage V')),
              Expanded(child: _MapMetric(icon: Icons.speed_rounded, label: 'وضعیت خودرو', value: ignition == true ? 'ACC روشن' : ignition == false ? 'ACC خاموش' : '—')),
              Expanded(child: _MapMetric(icon: Icons.refresh_rounded, label: 'آخرین بروزرسانی', value: position?['serverTime']?.toString() ?? '—')),
              Expanded(child: _MapMetric(icon: Icons.speed_rounded, label: 'سرعت', value: speed == null ? '—' : '${(speed * 1.852).toStringAsFixed(0)} km/h')),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MapAction({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      borderRadius: BorderRadius.circular(15),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 21),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MapMetric({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: MtColors.red, size: 24),
        const SizedBox(height: 6),
        Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
      ],
    );
  }
}

class _AlertsTab extends StatelessWidget {
  final List<dynamic> events;
  final bool hasDevice;
  final Map<String, dynamic> capabilities;
  final bool protection;
  final VoidCallback onProtection;
  final VoidCallback onVoice;
  final VoidCallback onFind;
  final VoidCallback onSiren;
  final VoidCallback onEngineStop;
  final VoidCallback onEngineResume;

  const _AlertsTab({
    required this.events,
    required this.hasDevice,
    required this.capabilities,
    required this.protection,
    required this.onProtection,
    required this.onVoice,
    required this.onFind,
    required this.onSiren,
    required this.onEngineStop,
    required this.onEngineResume,
  });

  @override
  Widget build(BuildContext context) {
    bool cap(String key, {bool fallback = false}) =>
        capabilities.containsKey(key) ? capabilities[key] == true : fallback;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        const MtSectionTitle(
          title: 'کنترل‌های امنیتی',
          subtitle: 'مدیریت و کنترل امنیت خودرو از راه دور',
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 14),
        MtCard(
          child: Column(
            children: [
              Row(
                textDirection: TextDirection.ltr,
                children: [
                  Expanded(
                    child: _SecurityAction(
                      icon: Icons.my_location_rounded,
                      title: 'یافتن خودرو',
                      status: hasDevice ? 'فعال' : 'غیرفعال',
                      good: hasDevice,
                      onTap: onFind,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SecurityAction(
                      icon: Icons.campaign_rounded,
                      title: 'آژیر خودرو',
                      status: 'خاموش',
                      selected: true,
                      onTap: hasDevice && cap('siren') ? onSiren : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SecurityAction(
                      icon: Icons.shield_outlined,
                      title: 'محافظت',
                      status: protection ? 'فعال' : 'غیرفعال',
                      good: protection,
                      onTap: hasDevice ? onProtection : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                textDirection: TextDirection.ltr,
                children: [
                  Expanded(
                    child: _SecurityAction(
                      icon: Icons.headphones_rounded,
                      title: 'شنود آنلاین',
                      status: hasDevice ? 'فعال' : 'غیرفعال',
                      good: hasDevice,
                      onTap: hasDevice && cap('voiceMonitor') ? onVoice : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SecurityAction(
                      icon: Icons.power_settings_new_rounded,
                      title: 'قطع موتور',
                      status: 'خاموش',
                      onTap: hasDevice && cap('engineControl') ? onEngineStop : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: hasDevice && cap('engineControl') ? onEngineResume : null,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('وصل مجدد موتور'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MtCard(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MtSectionTitle(
                title: 'هشدارها و رویدادهای اخیر',
                icon: Icons.notifications_none_rounded,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FilterChip(label: 'همه', selected: true),
                  const SizedBox(width: 8),
                  const _FilterChip(label: 'امنیتی'),
                  const SizedBox(width: 8),
                  const _FilterChip(label: 'سیستمی'),
                ],
              ),
              const SizedBox(height: 10),
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Text(
                    'هنوز رویداد واقعی از دستگاه/سرور ثبت نشده است.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...events.map((e) => _EventRow(event: Map<String, dynamic>.from(e as Map))),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecurityAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final bool good;
  final bool selected;
  final VoidCallback? onTap;

  const _SecurityAction({
    required this.icon,
    required this.title,
    required this.status,
    this.good = false,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MtColors.red : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 138,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? Colors.white.withOpacity(.6) : Colors.grey.withOpacity(.12)),
            boxShadow: selected ? [BoxShadow(color: MtColors.red.withOpacity(.35), blurRadius: 18)] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? Colors.white : (title == 'قطع موتور' ? MtColors.red : Theme.of(context).colorScheme.onSurface), size: 33),
              const SizedBox(height: 9),
              Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: selected ? Colors.white : null)),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(.85)
                      : (good ? Colors.green : Colors.grey).withOpacity(.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: selected ? MtColors.red : (good ? Colors.green : Colors.grey),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _FilterChip({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? MtColors.red : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: selected ? MtColors.red : Colors.grey.withOpacity(.2)),
      ),
      child: Text(
        label,
        style: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w800, fontSize: 11.5),
      ),
    );
  }
}

class _SupportTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const _SupportTab({required this.baseUrl, required this.token});

  @override
  State<_SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<_SupportTab> {
  late final SupportApi api;
  List<dynamic>? tickets;
  final subject = TextEditingController();
  final message = TextEditingController();
  bool sending = false;

  @override
  void initState() {
    super.initState();
    api = SupportApi(widget.baseUrl, widget.token);
    _load();
  }

  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await api.tickets();
      if (mounted) setState(() => tickets = rows);
    } catch (_) {
      if (mounted) setState(() => tickets = const []);
    }
  }

  Future<void> _newTicket() async {
    subject.clear();
    message.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> submit() async {
            if (subject.text.trim().isEmpty || message.text.trim().isEmpty) return;
            setLocal(() => sending = true);
            try {
              await api.createTicket(subject: subject.text.trim(), message: message.text.trim());
              if (context.mounted) Navigator.pop(context);
              await _load();
            } finally {
              if (mounted) setState(() => sending = false);
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(18, 8, 18, MediaQuery.of(context).viewInsets.bottom + 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تیکت جدید', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                TextField(controller: subject, decoration: const InputDecoration(labelText: 'موضوع')),
                const SizedBox(height: 10),
                TextField(controller: message, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'پیام شما')),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: MtRedButton(label: sending ? 'در حال ارسال...' : 'ارسال تیکت', icon: Icons.send_rounded, onPressed: sending ? null : submit),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openTicket(Map<String, dynamic> ticket) async {
    final idRaw = ticket['id'];
    final id = idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '');
    if (id == null) return;

    Map<String, dynamic>? detail;
    try {
      detail = await api.ticket(id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جزئیات تیکت در دسترس نیست.')),
        );
      }
      return;
    }
    if (!mounted) return;

    final input = TextEditingController();
    var messages = detail!['messages'] is List
        ? List<dynamic>.from(detail['messages'] as List)
        : <dynamic>[];
    bool posting = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> send() async {
            final text = input.text.trim();
            if (text.isEmpty || posting) return;
            setLocal(() => posting = true);
            try {
              final created = await api.sendMessage(ticketId: id, message: text);
              input.clear();
              messages = [...messages, created];
              detail = {...detail!, 'messages': messages};
              setLocal(() => posting = false);
              await _load();
            } catch (_) {
              setLocal(() => posting = false);
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .72,
              child: Column(
                children: [
                  Row(
                    children: [
                      MtStatusPill(
                        text: '${ticket['status'] ?? 'open'}',
                        color: ticket['status'] == 'answered' ? Colors.green : Colors.orange,
                      ),
                      const Spacer(),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${ticket['subject'] ?? 'پشتیبانی'}  #TK-$id',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: messages.isEmpty
                        ? const Center(child: Text('پیامی ثبت نشده است.'))
                        : ListView.builder(
                            itemCount: messages.length,
                            itemBuilder: (context, i) {
                              final m = Map<String, dynamic>.from(messages[i] as Map);
                              final mine = m['sender_role'] == 'user';
                              return Align(
                                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 360),
                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? MtColors.red.withOpacity(.08)
                                        : Colors.grey.withOpacity(.08),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${m['message'] ?? ''}', style: const TextStyle(height: 1.5)),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${m['created_at'] ?? ''}',
                                        style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          decoration: const InputDecoration(
                            hintText: 'پیام خود را بنویسید',
                            prefixIcon: Icon(Icons.attach_file_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: FilledButton(
                          onPressed: posting ? null : send,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                          ),
                          child: const Icon(Icons.send_rounded),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    input.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        MtCard(
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(color: MtColors.red.withOpacity(.07), shape: BoxShape.circle),
                child: const Icon(Icons.support_agent_rounded, color: MtColors.red, size: 36),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: MtSectionTitle(
                  title: 'پشتیبانی و تماس',
                  subtitle: 'ما اینجاییم تا به شما کمک کنیم',
                ),
              ),
              SizedBox(
                width: 150,
                child: MtRedButton(label: 'تیکت جدید', icon: Icons.add_rounded, onPressed: _newTicket),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const MtSectionTitle(title: 'تیکت‌های من', icon: Icons.list_alt_rounded),
        const SizedBox(height: 10),
        MtCard(
          padding: EdgeInsets.zero,
          child: tickets == null
              ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
              : tickets!.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: Text('تیکتی ثبت نشده است.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < tickets!.length; i++) ...[
                          _TicketRow(
                            ticket: Map<String, dynamic>.from(tickets![i] as Map),
                            onTap: () => _openTicket(Map<String, dynamic>.from(tickets![i] as Map)),
                          ),
                          if (i != tickets!.length - 1) const MtDivider(),
                        ],
                      ],
                    ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MtCard(
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFFFFECEE),
                      child: Icon(Icons.chat_bubble_outline_rounded, color: MtColors.red),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('پشتیبانی درون‌برنامه', style: TextStyle(fontWeight: FontWeight.w900)),
                          SizedBox(height: 4),
                          Text('از طریق تیکت با ما در ارتباط باشید', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          SizedBox(height: 5),
                          Text('● آنلاین', style: TextStyle(fontSize: 10, color: Colors.green)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MtCard(
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFFFFECEE),
                      child: Icon(Icons.email_outlined, color: MtColors.red),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ایمیل پشتیبانی', style: TextStyle(fontWeight: FontWeight.w900)),
                          SizedBox(height: 4),
                          Text('آدرس از Remote Config سرور قابل تنظیم است', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TicketRow extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;

  const _TicketRow({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = ticket['status']?.toString() ?? 'open';
    final color = status == 'answered' || status == 'closed'
        ? Colors.green
        : status == 'pending'
            ? Colors.orange
            : Colors.green;
    final label = status == 'answered'
        ? 'پاسخ داده شد'
        : status == 'pending'
            ? 'در حال بررسی'
            : status == 'closed'
                ? 'بسته'
                : 'باز';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Icon(Icons.chevron_left_rounded),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: Text('${ticket['created_at'] ?? ''}', style: const TextStyle(fontSize: 9.5, color: Colors.grey))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${ticket['subject'] ?? 'پشتیبانی'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('#TK-${ticket['id'] ?? '—'}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          MtStatusPill(text: label, color: color),
        ],
      ),
      ),
    );
  }
}

class _AccountTab extends StatefulWidget {
  final String baseUrl;
  final String token;
  final bool darkMode;
  final AppBootstrap? bootstrap;
  final int? deviceId;
  final bool deviceOnline;
  final VoidCallback onTheme;
  final VoidCallback onLogout;
  final VoidCallback onAddDevice;

  const _AccountTab({
    required this.baseUrl,
    required this.token,
    required this.darkMode,
    required this.bootstrap,
    required this.deviceId,
    required this.deviceOnline,
    required this.onTheme,
    required this.onLogout,
    required this.onAddDevice,
  });

  @override
  State<_AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<_AccountTab> {
  late final AccountApi api;

  @override
  void initState() {
    super.initState();
    api = AccountApi(widget.baseUrl, token: widget.token);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.bootstrap?.user ?? const <String, dynamic>{};
    final sub = widget.bootstrap?.subscription ?? const <String, dynamic>{};
    final days = sub['daysRemaining'] ?? 0;
    final active = sub['active'] == true;
    final offline = sub['offline'] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('حساب کاربری', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ),
            _SmallChoice(icon: Icons.language_rounded, label: 'FA'),
            const SizedBox(width: 8),
            _SmallChoice(icon: widget.darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, label: widget.darkMode ? 'تیره' : 'روشن'),
          ],
        ),
        const SizedBox(height: 14),
        MtCard(
          child: Row(
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withOpacity(.14),
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: const Icon(Icons.person_rounded, size: 72, color: Colors.grey),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('کاربر MTcar', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('@${user['username'] ?? '—'}', style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 10),
                    MtStatusPill(
                      text: offline ? 'حالت آفلاین' : active ? 'اشتراک فعال' : 'اشتراک منقضی',
                      color: offline ? Colors.grey : active ? Colors.green : MtColors.red,
                    ),
                    const SizedBox(height: 8),
                    if (offline)
                      const Row(
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 18, color: Colors.grey),
                          SizedBox(width: 6),
                          Text('اتصال به سرور برقرار نیست', style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text('$days روز تا پایان اشتراک', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MtCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _AccountRow(icon: Icons.person_outline_rounded, title: 'اطلاعات کاربری', onTap: () {}),
              const MtDivider(),
              _AccountRow(icon: Icons.lock_outline_rounded, title: 'تغییر رمز عبور', onTap: _changePassword),
              const MtDivider(),
              _AccountRow(icon: Icons.language_rounded, title: 'زبان برنامه', value: 'FA / EN', onTap: () {}),
              const MtDivider(),
              _AccountRow(icon: Icons.light_mode_outlined, title: 'حالت نمایش', value: widget.darkMode ? 'تیره' : 'روشن', onTap: widget.onTheme),
              const MtDivider(),
              _AccountRow(
                icon: Icons.credit_card_outlined,
                title: 'اشتراک و پرداخت',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubscriptionPage(
                        baseUrl: widget.baseUrl,
                        token: widget.token,
                        darkMode: widget.darkMode,
                        onTheme: widget.onTheme,
                      ),
                    ),
                  );
                },
              ),
              const MtDivider(),
              _AccountRow(
                icon: Icons.settings_outlined,
                title: 'تنظیمات دستگاه',
                onTap: () {
                  if (widget.deviceId == null) {
                    widget.onAddDevice();
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeviceSettingsPage(
                        baseUrl: widget.baseUrl,
                        token: widget.token,
                        deviceId: widget.deviceId,
                        deviceOnline: widget.deviceOnline,
                        darkMode: widget.darkMode,
                        onTheme: widget.onTheme,
                      ),
                    ),
                  );
                },
              ),
              const MtDivider(),
              _AccountRow(icon: Icons.info_outline_rounded, title: 'درباره ما و تماس', onTap: () {}),
              const MtDivider(),
              _AccountRow(icon: Icons.logout_rounded, title: 'خروج از حساب', danger: true, onTap: widget.onLogout),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغییر رمز عبور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'رمز فعلی')),
            const SizedBox(height: 10),
            TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'رمز جدید')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          FilledButton(
            onPressed: () async {
              try {
                await api.changePassword(currentPassword: current.text, newPassword: next.text);
                if (context.mounted) Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('رمز عبور تغییر کرد.')));
              } catch (_) {
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('تغییر رمز انجام نشد.')));
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
  }

}

class _SmallChoice extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SmallChoice({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(.12)),
      ),
      child: Row(children: [Icon(icon, size: 19), const SizedBox(width: 6), Text(label)]),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final bool danger;
  final VoidCallback onTap;

  const _AccountRow({required this.icon, required this.title, this.value, this.danger = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: danger ? MtColors.red : null),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: danger ? MtColors.red : null)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) Text(value!, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
          const SizedBox(width: 7),
          const Icon(Icons.chevron_left_rounded),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SubscriptionStrip extends StatelessWidget {
  final Map<String, dynamic> subscription;

  const _SubscriptionStrip({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final active = subscription['active'] == true;
    final offline = subscription['offline'] == true;
    final days = subscription['daysRemaining'];
    final accent = offline ? Colors.grey : (active ? Colors.green : MtColors.red);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            offline
                ? Icons.cloud_off_rounded
                : active
                    ? Icons.verified_outlined
                    : Icons.workspace_premium_outlined,
            color: accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              offline
                  ? 'حالت آفلاین: وضعیت اشتراک و سرویس‌های ابری پس از اتصال به سرور بررسی می‌شوند.'
                  : active
                      ? 'اعتبار حساب: ${days ?? '—'} روز باقی‌مانده'
                      : 'دوره اعتبار به پایان رسیده است. برای ادامه سرویس‌های ابری اشتراک را تمدید کنید.',
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiryBanner extends StatelessWidget {
  final String text;
  final VoidCallback onRenew;

  const _ExpiryBanner({required this.text, required this.onRenew});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: MtColors.red.withOpacity(.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: MtColors.red.withOpacity(.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_outlined, color: MtColors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
          TextButton(onPressed: onRenew, child: const Text('تمدید')),
        ],
      ),
    );
  }
}
