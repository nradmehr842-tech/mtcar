import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app/mtcar_theme.dart';
import '../services/api.dart';
import '../widgets/mtcar_design.dart';

class RouteReplayPage extends StatefulWidget {
  final String? baseUrl;
  final String? token;
  final int? deviceId;
  final bool darkMode;
  final VoidCallback? onTheme;

  const RouteReplayPage({
    super.key,
    this.baseUrl,
    this.token,
    this.deviceId,
    this.darkMode = false,
    this.onTheme,
  });

  @override
  State<RouteReplayPage> createState() => _RouteReplayPageState();
}

class _RouteReplayPageState extends State<RouteReplayPage> {
  DateTime date = DateTime.now();
  TimeOfDay from = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay to = const TimeOfDay(hour: 16, minute: 0);
  List<LatLng> points = [];
  List<dynamic> routeRows = [];
  bool loading = false;
  double progress = 0;
  double speedFactor = 1;

  late final FleetApi? api;

  @override
  void initState() {
    super.initState();
    api = widget.baseUrl != null && widget.token != null
        ? FleetApi(widget.baseUrl!, widget.token!)
        : null;
  }

  DateTime _at(TimeOfDay time) => DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDate: date,
    );
    if (result != null) setState(() => date = result);
  }

  Future<void> _pickTime(bool start) async {
    final result = await showTimePicker(
      context: context,
      initialTime: start ? from : to,
    );
    if (result != null) {
      setState(() {
        if (start) {
          from = result;
        } else {
          to = result;
        }
      });
    }
  }

  Future<void> _loadRoute() async {
    if (api == null || widget.deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برای دریافت مسیر واقعی ابتدا دستگاه را به حساب متصل کنید.')),
      );
      return;
    }

    final start = _at(from);
    final end = _at(to);
    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ساعت پایان باید بعد از ساعت شروع باشد.')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      final rows = await api!.route(widget.deviceId!, start, end);
      final routePoints = rows
          .where((x) => x is Map && x['latitude'] != null && x['longitude'] != null)
          .map((x) => LatLng(
                (x['latitude'] as num).toDouble(),
                (x['longitude'] as num).toDouble(),
              ))
          .toList();
      if (!mounted) return;
      setState(() {
        routeRows = rows;
        points = routePoints;
        progress = routePoints.isEmpty ? 0 : 1;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('دریافت مسیر از سرور انجام نشد.')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  double _maxSpeedKmh() {
    double max = 0;
    for (final raw in routeRows) {
      if (raw is! Map) continue;
      final speed = raw['speed'];
      if (speed is num) {
        final kmh = speed.toDouble() * 1.852;
        if (kmh > max) max = kmh;
      }
    }
    return max;
  }

  Duration _stoppedDuration() {
    if (routeRows.length < 2) return Duration.zero;
    Duration total = Duration.zero;
    for (var i = 1; i < routeRows.length; i++) {
      final prev = routeRows[i - 1];
      final cur = routeRows[i];
      if (prev is! Map || cur is! Map) continue;
      final speed = prev['speed'];
      if (speed is! num || speed.toDouble() * 1.852 > 2) continue;
      final a = DateTime.tryParse((prev['fixTime'] ?? prev['deviceTime'] ?? prev['serverTime'] ?? '').toString());
      final b = DateTime.tryParse((cur['fixTime'] ?? cur['deviceTime'] ?? cur['serverTime'] ?? '').toString());
      if (a == null || b == null || !b.isAfter(a)) continue;
      final delta = b.difference(a);
      if (delta <= const Duration(minutes: 20)) total += delta;
    }
    return total;
  }

  String _durationText(Duration d) {
    if (d == Duration.zero) return '—';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
  double _distanceKm() {
    if (points.length < 2) return 0;
    const d = Distance();
    double meters = 0;
    for (var i = 1; i < points.length; i++) {
      meters += d(points[i - 1], points[i]);
    }
    return meters / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = const LatLng(35.7219, 51.3347);
    final center = points.isNotEmpty ? points[points.length ~/ 2] : fallback;
    final displayedCount = points.isEmpty
        ? 0
        : (points.length * progress.clamp(0, 1)).round().clamp(1, points.length).toInt();
    final shownPoints = points.take(displayedCount).toList();

    return Scaffold(
      body: Column(
        children: [
          MtPremiumHeader(
            onTheme: widget.onTheme ?? () {},
            darkMode: widget.darkMode,
            showBack: true,
            notificationCount: 0,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
              children: [
                MtCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MtSectionTitle(
                        title: 'پخش مسیر',
                        icon: Icons.history_rounded,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _PickerBox(
                              label: 'تاریخ',
                              value: '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
                              icon: Icons.calendar_month_outlined,
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _PickerBox(
                              label: 'از ساعت',
                              value: from.format(context),
                              icon: Icons.schedule_rounded,
                              onTap: () => _pickTime(true),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _PickerBox(
                              label: 'تا ساعت',
                              value: to.format(context),
                              icon: Icons.schedule_rounded,
                              onTap: () => _pickTime(false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      MtRedButton(
                        label: loading ? 'در حال دریافت...' : 'نمایش پخش مسیر',
                        onPressed: loading ? null : _loadRoute,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 520,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: points.isEmpty ? 11 : 13,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'ir.mediatelecom.mtcar',
                        ),
                        if (shownPoints.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: shownPoints,
                                strokeWidth: 5,
                                color: MtColors.red,
                              ),
                            ],
                          ),
                        if (points.isNotEmpty)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: points.first,
                                width: 80,
                                height: 80,
                                child: const _RouteMarker(
                                  color: Colors.green,
                                  label: 'شروع',
                                ),
                              ),
                              Marker(
                                point: points.last,
                                width: 80,
                                height: 80,
                                child: const _RouteMarker(
                                  color: MtColors.red,
                                  label: 'پایان',
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                MtCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MtColors.red.withOpacity(.08),
                        ),
                        child: IconButton(
                          onPressed: points.isEmpty
                              ? null
                              : () => setState(() {
                                    progress = progress >= 1 ? 0 : (progress + .12).clamp(0, 1);
                                  }),
                          icon: const Icon(Icons.play_arrow_rounded, color: MtColors.red),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(from.format(context)),
                      Expanded(
                        child: Slider(
                          value: progress,
                          activeColor: MtColors.red,
                          onChanged: points.isEmpty ? null : (v) => setState(() => progress = v),
                        ),
                      ),
                      Text(to.format(context)),
                      const SizedBox(width: 8),
                      DropdownButton<double>(
                        value: speedFactor,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1x')),
                          DropdownMenuItem(value: 2, child: Text('2x')),
                          DropdownMenuItem(value: 4, child: Text('4x')),
                        ],
                        onChanged: (v) => setState(() => speedFactor = v ?? 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.route_rounded,
                        iconColor: Colors.blue,
                        value: _distanceKm() == 0 ? '—' : _distanceKm().toStringAsFixed(1),
                        label: 'مسافت',
                        unit: _distanceKm() == 0 ? '' : 'کیلومتر',
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.timer_outlined,
                        iconColor: Colors.orange,
                        value: _durationText(_stoppedDuration()),
                        label: 'مدت توقف',
                        unit: '',
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.speed_rounded,
                        iconColor: Colors.deepPurple,
                        value: _maxSpeedKmh() == 0 ? '—' : _maxSpeedKmh().toStringAsFixed(0),
                        label: 'حداکثر سرعت',
                        unit: _maxSpeedKmh() == 0 ? '' : 'km/h',
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.location_on_outlined,
                        iconColor: Colors.green,
                        value: points.isEmpty ? '—' : '${points.length}',
                        label: 'تعداد نقاط ثبت‌شده',
                        unit: points.isEmpty ? '' : 'نقطه',
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
}

class _PickerBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(.18)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
                Icon(icon, size: 19),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMarker extends StatelessWidget {
  final Color color;
  final String label;

  const _RouteMarker({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.location_on_rounded, color: color, size: 42),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)],
          ),
          child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String unit;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return MtCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 7),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          if (unit.isNotEmpty)
            Text(unit, style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        ],
      ),
    );
  }
}
