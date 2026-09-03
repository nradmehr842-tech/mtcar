import 'package:flutter/material.dart';
import '../services/map_preferences_api.dart';
import '../widgets/mtcar_design.dart';

class MapSettingsPage extends StatefulWidget {
  final String? baseUrl;
  final String? token;

  const MapSettingsPage({super.key, this.baseUrl, this.token});

  @override
  State<MapSettingsPage> createState() => _MapSettingsPageState();
}

class _MapSettingsPageState extends State<MapSettingsPage> {
  String mapProvider = 'auto';
  String navigationProvider = 'waze';
  String mapStyle = 'standard';
  bool loading = false;
  bool saving = false;
  Map<String, dynamic> availability = const {};
  MapPreferencesApi? api;

  @override
  void initState() {
    super.initState();
    if (widget.baseUrl != null && widget.token != null) {
      api = MapPreferencesApi(widget.baseUrl!, widget.token!);
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await api!.load();
      if (!mounted) return;
      final pref = data['preferences'] is Map
          ? Map<String, dynamic>.from(data['preferences'] as Map)
          : data;
      setState(() {
        availability = data['availability'] is Map
            ? Map<String, dynamic>.from(data['availability'] as Map)
            : const {};
        mapProvider = (pref['map_provider'] ?? pref['mapProvider'])?.toString() ?? mapProvider;
        navigationProvider = (pref['navigation_provider'] ?? pref['navigationProvider'])?.toString() ?? navigationProvider;
        mapStyle = (pref['map_style'] ?? pref['mapStyle'])?.toString() ?? mapStyle;
      });
    } catch (_) {
      // Keep safe local defaults when preferences are unavailable.
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    if (api == null || saving) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تنظیمات روی این نسخه به سرور متصل نیست.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await api!.save(
        mapProvider: mapProvider,
        navigationProvider: navigationProvider,
        mapStyle: mapStyle,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تنظیمات نقشه ذخیره شد.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ذخیره تنظیمات نقشه انجام نشد.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const MtSectionTitle(
          title: 'نقشه و مسیریابی',
          subtitle: 'نقشه داخل MTcar و برنامه مسیریابی را جداگانه انتخاب کنید.',
          icon: Icons.map_outlined,
        ),
        if (loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 16),
        MtCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.map_outlined),
                title: Text('نقشه پیش‌فرض داخل MTcar', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              RadioListTile<String>(
                value: 'auto',
                groupValue: mapProvider,
                onChanged: (v) => setState(() => mapProvider = v!),
                title: const Text('خودکار'),
                subtitle: const Text('بهترین Provider فعال روی سرور'),
              ),
              RadioListTile<String>(
                value: 'google',
                groupValue: mapProvider,
                onChanged: availability['googleConfigured'] == true ? (v) => setState(() => mapProvider = v!) : null,
                title: const Text('Google Maps'),
                subtitle: const Text('فقط با API Key/SDK رسمی'),
              ),
              RadioListTile<String>(
                value: 'neshan',
                groupValue: mapProvider,
                onChanged: availability['neshanConfigured'] == true ? (v) => setState(() => mapProvider = v!) : null,
                title: const Text('نشان'),
                subtitle: const Text('فقط با دسترسی رسمی'),
              ),
              RadioListTile<String>(
                value: 'balad',
                groupValue: mapProvider,
                onChanged: availability['baladConfigured'] == true ? (v) => setState(() => mapProvider = v!) : null,
                title: const Text('بلد'),
                subtitle: const Text('فقط با API/SDK رسمی؛ Endpoint حدسی استفاده نمی‌شود'),
              ),
              RadioListTile<String>(
                value: 'osm',
                groupValue: mapProvider,
                onChanged: (v) => setState(() => mapProvider = v!),
                title: const Text('OpenStreetMap'),
                subtitle: const Text('Fallback'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MtCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.navigation_outlined),
                title: Text('مسیریاب پیش‌فرض', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              RadioListTile<String>(
                value: 'waze',
                groupValue: navigationProvider,
                onChanged: (v) => setState(() => navigationProvider = v!),
                title: const Text('Waze'),
                subtitle: const Text('به‌صورت Deep-link خارجی؛ نه Basemap داخلی'),
              ),
              RadioListTile<String>(
                value: 'google',
                groupValue: navigationProvider,
                onChanged: availability['googleConfigured'] == true ? (v) => setState(() => navigationProvider = v!) : null,
                title: const Text('Google Maps'),
              ),
              RadioListTile<String>(
                value: 'neshan',
                groupValue: navigationProvider,
                onChanged: availability['neshanConfigured'] == true ? (v) => setState(() => navigationProvider = v!) : null,
                title: const Text('نشان'),
              ),
              RadioListTile<String>(
                value: 'balad',
                groupValue: navigationProvider,
                onChanged: availability['baladConfigured'] == true ? (v) => setState(() => navigationProvider = v!) : null,
                title: const Text('بلد'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: mapStyle,
          decoration: const InputDecoration(labelText: 'نمای نقشه'),
          items: const [
            DropdownMenuItem(value: 'standard', child: Text('استاندارد')),
            DropdownMenuItem(value: 'satellite', child: Text('ماهواره‌ای')),
            DropdownMenuItem(value: 'dark', child: Text('تیره')),
          ],
          onChanged: (v) => setState(() => mapStyle = v!),
        ),
        const SizedBox(height: 16),
        MtRedButton(
          label: saving ? 'در حال ذخیره...' : 'ذخیره تنظیمات نقشه',
          onPressed: saving ? null : _save,
        ),
      ],
    );
  }
}
