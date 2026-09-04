import 'package:flutter/material.dart';
import '../services/alert_bridge.dart';
import '../services/device_models_api.dart';
import '../services/device_onboarding_api.dart';

class AddDeviceSheet extends StatefulWidget {
  final String baseUrl;
  final String token;
  final VoidCallback onCreated;

  const AddDeviceSheet({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.onCreated,
  });

  @override
  State<AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<AddDeviceSheet> {
  final vehicleName = TextEditingController(text: 'خودروی من');
  final imei = TextEditingController();
  final simPhone = TextEditingController();
  final trackerPassword = TextEditingController(text: '123456');

  List<dynamic> models = [];
  int? modelId;
  String operatorName = 'MCI';
  String vehicleType = 'car';
  bool loadingModels = true;
  bool saving = false;
  bool enableSmsBackup = false;
  String? error;

  late final DeviceModelsApi modelsApi;
  late final DeviceOnboardingApi onboardingApi;

  @override
  void initState() {
    super.initState();
    modelsApi = DeviceModelsApi(widget.baseUrl, widget.token);
    onboardingApi = DeviceOnboardingApi(widget.baseUrl, widget.token);
    _loadModels();
  }

  @override
  void dispose() {
    vehicleName.dispose();
    imei.dispose();
    simPhone.dispose();
    trackerPassword.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    try {
      final rows = await modelsApi.models();
      if (!mounted) return;
      setState(() {
        models = rows;
        modelId = rows.isEmpty ? null : rows.first['id'] as int?;
        loadingModels = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingModels = false;
        error = 'دریافت مدل‌های ردیاب از سرور انجام نشد.';
      });
    }
  }

  Future<void> _save() async {
    if (saving) return;

    final id = imei.text.trim();
    final sim = simPhone.text.trim();
    if (id.length < 6) {
      setState(() => error = 'IMEI / شناسه دستگاه را صحیح وارد کنید.');
      return;
    }
    if (sim.isEmpty) {
      setState(() => error = 'شماره سیم‌کارت داخل ردیاب را وارد کنید.');
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await onboardingApi.create(
        imei: id,
        trackerSimPhone: sim,
        trackerSimOperator: operatorName,
        vehicleName: vehicleName.text.trim().isEmpty
            ? 'خودروی من'
            : vehicleName.text.trim(),
        vehicleType: vehicleType,
        deviceModelId: modelId,
      );

      // SMS Backup is optional and is not required for account creation or
      // normal server-based tracking. Permissions are requested only when the
      // user explicitly enables this fallback.
      if (enableSmsBackup) {
        await AlertBridge.configure(
          trackerPhone: sim,
          trackerPassword: trackerPassword.text.trim(),
          enabled: true,
        );
        await AlertBridge.requestPermissions();
      } else {
        await AlertBridge.configure(
          trackerPhone: sim,
          trackerPassword: trackerPassword.text.trim(),
          enabled: false,
        );
      }

      if (!mounted) return;
      widget.onCreated();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(.35),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded),
                  SizedBox(width: 8),
                  Text(
                    'افزودن ردیاب',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (loadingModels)
                const LinearProgressIndicator()
              else if (models.isEmpty)
                const ListTile(
                  leading: Icon(Icons.warning_amber_rounded),
                  title: Text('مدل فعالی در پنل مدیریت تعریف نشده است.'),
                )
              else ...[
                if (models.length == 1)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.gps_fixed_rounded),
                    ),
                    title: Text(
                      '${models.first['brand']} ${models.first['display_name']}',
                    ),
                    subtitle: Text(
                      '${models.first['protocol']} • Port ${models.first['server_port']}',
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    value: modelId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'مدل ردیاب',
                      prefixIcon: Icon(Icons.gps_fixed_rounded),
                    ),
                    items: models.map((m) {
                      return DropdownMenuItem<int>(
                        value: m['id'] as int,
                        child: Text(
                          '${m['brand']} ${m['display_name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => modelId = v),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: vehicleName,
                  decoration: const InputDecoration(
                    labelText: 'نام خودرو',
                    prefixIcon: Icon(Icons.directions_car_filled_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imei,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'IMEI / شناسه ردیاب',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: simPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'شماره سیم‌کارت ردیاب',
                    prefixIcon: Icon(Icons.sim_card_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: operatorName,
                  decoration: const InputDecoration(
                    labelText: 'اپراتور سیم‌کارت',
                    prefixIcon: Icon(Icons.signal_cellular_alt_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'MCI', child: Text('همراه اول')),
                    DropdownMenuItem(value: 'Irancell', child: Text('ایرانسل')),
                    DropdownMenuItem(value: 'Other', child: Text('سایر')),
                  ],
                  onChanged: (v) =>
                      setState(() => operatorName = v ?? 'MCI'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: vehicleType,
                  decoration: const InputDecoration(
                    labelText: 'نوع وسیله',
                    prefixIcon: Icon(Icons.commute_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'car', child: Text('خودرو')),
                    DropdownMenuItem(
                      value: 'motorcycle',
                      child: Text('موتورسیکلت'),
                    ),
                  ],
                  onChanged: (v) => setState(() => vehicleType = v ?? 'car'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: enableSmsBackup,
                  onChanged: (v) => setState(() => enableSmsBackup = v),
                  title: const Text('SMS Backup (اختیاری)'),
                  subtitle: const Text(
                    'برای ثبت‌نام یا رهگیری آنلاین لازم نیست؛ فقط برای فرمان/هشدار پشتیبان پیامکی.',
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: trackerPassword,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'رمز فرمان ردیاب',
                    prefixIcon: const Icon(Icons.password_rounded),
                    helperText: enableSmsBackup
                        ? 'این رمز برای فرمان‌های SMS روی همین گوشی نگهداری می‌شود.'
                        : 'در حالت عادی لازم نیست؛ برای SMS Backup اختیاری استفاده می‌شود.',
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed:
                      saving || loadingModels || models.isEmpty ? null : _save,
                  child: saving
                      ? const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        )
                      : const Text('ثبت و اتصال دستگاه'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
