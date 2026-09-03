import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const mtRed = Color(0xFFE10600);
const mtDarkRed = Color(0xFFB80000);
const mtLightGray = Color(0xFFF3F4F6);
const mtGraphite = Color(0xFF2B2F36);
const mtInk = Color(0xFF111827);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MtCarApp());
}

class MtCarApp extends StatefulWidget {
  const MtCarApp({super.key});

  @override
  State<MtCarApp> createState() => _MtCarAppState();
}

class _MtCarAppState extends State<MtCarApp> {
  bool dark = false;
  bool fa = true;
  bool authenticated = false;
  bool configured = false;

  ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0F12) : mtLightGray;
    final surface = isDark ? const Color(0xFF181B20) : Colors.white;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: mtRed,
        brightness: brightness,
        surface: surface,
        primary: mtRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: mtRed,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E5EA),
          ),
        ),
      ),
      dividerColor: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF12151A) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFD9DDE4),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: mtRed,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : mtInk,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFD6DAE1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: mtRed,
        indicatorColor: Colors.white.withOpacity(.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            color: Colors.white,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
        iconTheme: WidgetStateProperty.all(const IconThemeData(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (!authenticated) {
      home = AuthScreen(
        fa: fa,
        dark: dark,
        onTheme: () => setState(() => dark = !dark),
        onLanguage: () => setState(() => fa = !fa),
        onDone: () => setState(() => authenticated = true),
      );
    } else if (!configured) {
      home = SetupScreen(
        fa: fa,
        onDone: () => setState(() => configured = true),
      );
    } else {
      home = MainShell(
        fa: fa,
        dark: dark,
        onTheme: () => setState(() => dark = !dark),
        onLanguage: () => setState(() => fa = !fa),
      );
    }

    return MaterialApp(
      title: 'MTcar',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Directionality(
        textDirection: fa ? TextDirection.rtl : TextDirection.ltr,
        child: home,
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final bool fa;
  final bool dark;
  final VoidCallback onTheme;
  final VoidCallback onLanguage;
  final VoidCallback onDone;
  const AuthScreen({
    super.key,
    required this.fa,
    required this.dark,
    required this.onTheme,
    required this.onLanguage,
    required this.onDone,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool register = false;
  bool otpSent = false;
  final phone = TextEditingController(text: '0912');
  final pass = TextEditingController();
  final confirm = TextEditingController();
  final otp = TextEditingController();

  @override
  void dispose() {
    phone.dispose(); pass.dispose(); confirm.dispose(); otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(onPressed: widget.onTheme, icon: Icon(widget.dark ? Icons.light_mode : Icons.dark_mode)),
                      TextButton(onPressed: widget.onLanguage, child: Text(widget.fa ? 'EN' : 'FA')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const MtLogo(size: 88),
                  const SizedBox(height: 18),
                  Text('MTcar', style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    widget.fa ? 'امنیت و رهگیری هوشمند خودرو' : 'Smart vehicle security & tracking',
                    style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: false, label: Text(widget.fa ? 'ورود' : 'Login')),
                      ButtonSegment(value: true, label: Text(widget.fa ? 'ثبت‌نام' : 'Register')),
                    ],
                    selected: {register},
                    onSelectionChanged: (s) => setState(() { register = s.first; otpSent = false; }),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: widget.fa ? 'شماره موبایل' : 'Mobile number', prefixIcon: const Icon(Icons.phone_android)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pass,
                    obscureText: true,
                    decoration: InputDecoration(labelText: widget.fa ? 'رمز ورود' : 'Password', prefixIcon: const Icon(Icons.lock_outline)),
                  ),
                  if (register) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirm,
                      obscureText: true,
                      decoration: InputDecoration(labelText: widget.fa ? 'تکرار رمز' : 'Confirm password', prefixIcon: const Icon(Icons.lock_reset)),
                    ),
                    if (otpSent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: otp,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: widget.fa ? 'کد تایید پیامکی' : 'SMS verification code', prefixIcon: const Icon(Icons.sms_outlined)),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (register && !otpSent) {
                          setState(() => otpSent = true);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.fa ? 'کد تایید ارسال شد (نسخه آزمایشی)' : 'Verification code sent (demo)')));
                          return;
                        }
                        widget.onDone();
                      },
                      icon: Icon(register ? Icons.person_add_alt_1 : Icons.login),
                      label: Text(register ? (otpSent ? (widget.fa ? 'تایید و ادامه' : 'Verify & continue') : (widget.fa ? 'ارسال کد تایید' : 'Send code')) : (widget.fa ? 'ورود به MTcar' : 'Login to MTcar')),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(onPressed: () {}, child: Text(widget.fa ? 'رمز را فراموش کرده‌اید؟' : 'Forgot password?')),
                  const SizedBox(height: 20),
                  Text(
                    widget.fa ? 'با ادامه، قوانین استفاده و حریم خصوصی MTcar را می‌پذیرید.' : 'By continuing, you accept MTcar terms and privacy policy.',
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  final bool fa;
  final VoidCallback onDone;
  const SetupScreen({super.key, required this.fa, required this.onDone});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String type = 'MT120';
  String operator = 'همراه اول';
  String vehicleType = 'خودرو';
  final imei = TextEditingController();
  final sim = TextEditingController();
  final trackerPass = TextEditingController(text: '123456');
  final vehicleName = TextEditingController(text: 'پژو 206 تیپ 5');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MTcar')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(widget.fa ? 'راه‌اندازی اولیه دستگاه' : 'Initial device setup', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(widget.fa ? 'اطلاعات ردیاب نصب‌شده روی خودرو را وارد کنید. بعداً از تنظیمات دستگاه قابل ویرایش است.' : 'Enter the tracker information. You can edit it later.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 20),
                GlassCard(child: Column(children: [
                  DropdownButtonFormField<String>(value: type, decoration: InputDecoration(labelText: widget.fa ? 'نوع دستگاه' : 'Device model'), items: ['MT120','MT130','GPS Vehicle 12-PIN'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(), onChanged:(v)=>setState(()=>type=v!)),
                  const SizedBox(height: 12),
                  TextField(controller: imei, decoration: InputDecoration(labelText: 'IMEI', prefixIcon: const Icon(Icons.numbers))),
                  const SizedBox(height: 12),
                  TextField(controller: sim, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: widget.fa ? 'شماره سیم‌کارت داخل دستگاه' : 'Tracker SIM number', prefixIcon: const Icon(Icons.sim_card_outlined))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(value: operator, decoration: InputDecoration(labelText: widget.fa ? 'اپراتور سیم‌کارت' : 'SIM operator'), items: ['همراه اول','ایرانسل','رایتل'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(), onChanged:(v)=>setState(()=>operator=v!)),
                  const SizedBox(height: 12),
                  TextField(controller: trackerPass, obscureText: true, decoration: InputDecoration(labelText: widget.fa ? 'رمز دستگاه' : 'Tracker password', prefixIcon: const Icon(Icons.key))),
                ])),
                const SizedBox(height: 14),
                GlassCard(child: Column(children: [
                  TextField(controller: vehicleName, decoration: InputDecoration(labelText: widget.fa ? 'نام خودرو' : 'Vehicle name', prefixIcon: const Icon(Icons.directions_car))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(value: vehicleType, decoration: InputDecoration(labelText: widget.fa ? 'نوع وسیله' : 'Vehicle type'), items: ['خودرو','موتورسیکلت'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(), onChanged:(v)=>setState(()=>vehicleType=v!)),
                ])),
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: widget.onDone, icon: const Icon(Icons.check_circle_outline), label: Text(widget.fa ? 'ذخیره و ورود به برنامه' : 'Save and open app')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final bool fa;
  final bool dark;
  final VoidCallback onTheme;
  final VoidCallback onLanguage;
  const MainShell({super.key, required this.fa, required this.dark, required this.onTheme, required this.onLanguage});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  bool siren = false;
  bool armed = true;
  int unread = 3;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(fa: widget.fa, siren: siren, armed: armed, onSiren: () => setState(() => siren = !siren), onArm: () => setState(() => armed = !armed)),
      MapPage(fa: widget.fa),
      AlertsPage(fa: widget.fa, armed: armed, siren: siren, onArm: () => setState(() => armed = !armed), onSiren: () => setState(() => siren = !siren)),
      SupportPage(fa: widget.fa),
      AccountPage(fa: widget.fa, dark: widget.dark, onTheme: widget.onTheme, onLanguage: widget.onLanguage),
    ];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(118),
        child: MtHeader(
          fa: widget.fa,
          dark: widget.dark,
          unread: unread,
          onTheme: widget.onTheme,
          onLanguage: widget.onLanguage,
          onBell: () => setState(() { index = 2; unread = 0; }),
        ),
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.directions_car_filled_outlined), selectedIcon: const Icon(Icons.directions_car_filled), label: widget.fa ? 'خودروی من' : 'My car'),
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map), label: widget.fa ? 'نقشه' : 'Map'),
          NavigationDestination(icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_none)), selectedIcon: const Icon(Icons.notifications), label: widget.fa ? 'هشدارها' : 'Alerts'),
          NavigationDestination(icon: const Icon(Icons.support_agent_outlined), selectedIcon: const Icon(Icons.support_agent), label: widget.fa ? 'پشتیبانی' : 'Support'),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: widget.fa ? 'کاربری' : 'Account'),
        ],
      ),
    );
  }
}

class MtHeader extends StatelessWidget {
  final bool fa;
  final bool dark;
  final int unread;
  final VoidCallback onTheme;
  final VoidCallback onLanguage;
  final VoidCallback onBell;
  const MtHeader({super.key, required this.fa, required this.dark, required this.unread, required this.onTheme, required this.onLanguage, required this.onBell});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: mtRed,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 62,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(left: 10, child: IconButton(onPressed: onTheme, color: Colors.white, icon: Icon(dark ? Icons.light_mode : Icons.dark_mode))),
                  const Row(mainAxisSize: MainAxisSize.min, children: [MtLogo(size: 34, white: true), SizedBox(width: 8), Text('MTcar', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))]),
                  Positioned(right: 10, child: IconButton(onPressed: onBell, color: Colors.white, icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), backgroundColor: Colors.white, textColor: mtRed, child: const Icon(Icons.notifications_none))))
                ],
              ),
            ),
            Container(
              height: 50,
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
              child: Row(
                children: [
                  Expanded(child: TextButton.icon(onPressed: () {}, style: TextButton.styleFrom(foregroundColor: Colors.white), icon: const Icon(Icons.directions_car_outlined), label: Text(fa ? 'پژو 206 تیپ 5' : 'Peugeot 206 Type 5'))),
                  Container(width: 1, height: 24, color: Colors.white24),
                  SizedBox(width: 90, child: TextButton(onPressed: onLanguage, style: TextButton.styleFrom(foregroundColor: Colors.white), child: Text(fa ? 'English' : 'فارسی'))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final bool fa;
  final bool siren;
  final bool armed;
  final VoidCallback onSiren;
  final VoidCallback onArm;
  const HomePage({super.key, required this.fa, required this.siren, required this.armed, required this.onSiren, required this.onArm});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(children: [
          Expanded(child: StatusCard(icon: Icons.signal_cellular_alt, title: 'GSM', value: fa ? 'متصل' : 'Connected', good: true)),
          const SizedBox(width: 10),
          Expanded(child: StatusCard(icon: Icons.gps_fixed, title: 'GPS', value: fa ? '9 ماهواره' : '9 satellites', good: true)),
        ]),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: [
              Row(children: [
                Container(width: 70, height: 70, decoration: BoxDecoration(color: mtRed.withOpacity(.08), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.directions_car_filled, size: 44, color: mtRed)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fa ? 'پژو 206 تیپ 5' : 'Peugeot 206 Type 5', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Row(children: [const Icon(Icons.circle, color: Color(0xFF1C9B54), size: 10), const SizedBox(width: 6), Text(fa ? 'آنلاین • متوقف' : 'Online • Stopped')]),
                  const SizedBox(height: 4),
                  Text(fa ? 'آخرین بروزرسانی: همین الان' : 'Updated: just now', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                ])),
                Icon(armed ? Icons.shield : Icons.shield_outlined, color: armed ? const Color(0xFF1C9B54) : Colors.grey),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Metric(label: fa ? 'سوخت' : 'Fuel', value: '68%', icon: Icons.local_gas_station_outlined)),
                Expanded(child: Metric(label: fa ? 'باتری ردیاب' : 'Tracker battery', value: '87%', icon: Icons.battery_5_bar)),
                Expanded(child: Metric(label: fa ? 'سرعت' : 'Speed', value: '0 km/h', icon: Icons.speed)),
              ]),
              const SizedBox(height: 12),
              Row(children: [const Icon(Icons.location_on_outlined, color: mtRed), const SizedBox(width: 6), Expanded(child: Text(fa ? 'تهران، خیابان ولیعصر' : 'Tehran, Valiasr St.'))]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle(title: fa ? 'دسترسی سریع' : 'Quick actions'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: .9,
          children: [
            QuickAction(icon: Icons.location_searching, label: fa ? 'یافتن خودرو' : 'Find car', onTap: () => toast(context, fa ? 'موقعیت خودرو روی نقشه باز می‌شود.' : 'Vehicle location opens on map.')),
            QuickAction(icon: Icons.hearing_outlined, label: fa ? 'شنود آنلاین' : 'Live listen', danger: true, onTap: () => VoiceMonitor.start(context, fa)),
            QuickAction(icon: siren ? Icons.volume_up : Icons.campaign_outlined, label: fa ? 'آژیر خودرو' : 'Car siren', danger: siren, onTap: () { onSiren(); toast(context, siren ? (fa ? 'فرمان خاموش کردن آژیر ارسال شد.' : 'Siren off command sent.') : (fa ? 'فرمان روشن کردن آژیر ارسال شد.' : 'Siren on command sent.')); }),
            QuickAction(icon: armed ? Icons.shield : Icons.shield_outlined, label: fa ? 'محافظت' : 'Protection', active: armed, onTap: onArm),
            QuickAction(icon: Icons.alt_route, label: fa ? 'بازپخش مسیر' : 'Route replay', onTap: () => toast(context, fa ? 'از تب نقشه، بازپخش مسیر را باز کنید.' : 'Open Route Replay from Map tab.')),
            QuickAction(icon: Icons.radar, label: fa ? 'محدوده امن' : 'Geofence', onTap: () => toast(context, fa ? 'تنظیم محدوده امن در نسخه سرور فعال می‌شود.' : 'Geofence will activate with server.')),
            QuickAction(icon: Icons.power_settings_new, label: fa ? 'قطع موتور' : 'Engine cut', danger: true, onTap: () => EngineSafety.confirm(context, fa)),
            QuickAction(icon: Icons.local_gas_station, label: fa ? 'گزارش سوخت' : 'Fuel report', onTap: () => toast(context, fa ? 'گزارش سوخت نیازمند سنسور 0–5V است.' : 'Fuel report requires 0–5V sensor.')),
          ],
        ),
        const SizedBox(height: 16),
        SectionTitle(title: fa ? 'وضعیت سیستم' : 'System status'),
        const SizedBox(height: 8),
        GlassCard(child: Column(children: [
          const StatusRow(icon: Icons.door_front_door_outlined, title: 'Door', value: 'Closed', good: true),
          StatusRow(icon: Icons.key, title: 'ACC', value: fa ? 'خاموش' : 'OFF', good: true),
          StatusRow(icon: Icons.bolt, title: fa ? 'برق خودرو' : 'Vehicle power', value: 'ON', good: true),
          StatusRow(icon: Icons.vibration, title: fa ? 'ضربه / لرزش' : 'Shock', value: fa ? 'بدون هشدار' : 'No alert', good: true),
        ])),
      ],
    );
  }
}

class MapPage extends StatefulWidget {
  final bool fa;
  const MapPage({super.key, required this.fa});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  DateTime day = DateTime.now();
  TimeOfDay from = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay to = const TimeOfDay(hour: 18, minute: 0);
  double progress = .42;
  bool playing = false;
  Timer? timer;

  @override
  void dispose() { timer?.cancel(); super.dispose(); }

  void toggle() {
    setState(() => playing = !playing);
    timer?.cancel();
    if (playing) {
      timer = Timer.periodic(const Duration(milliseconds: 600), (_) {
        if (!mounted) return;
        setState(() {
          progress += .025;
          if (progress >= 1) { progress = 0; }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SectionTitle(title: widget.fa ? 'نقشه و بازپخش مسیر' : 'Map & route replay'),
        const SizedBox(height: 10),
        GlassCard(child: Column(children: [
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now().add(const Duration(days: 1)), initialDate: day); if (d != null) setState(()=>day=d); }, icon: const Icon(Icons.calendar_month), label: Text('${day.year}/${day.month.toString().padLeft(2,'0')}/${day.day.toString().padLeft(2,'0')}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () async { final x=await showTimePicker(context: context, initialTime: from); if(x!=null)setState(()=>from=x); }, icon: const Icon(Icons.schedule), label: Text(widget.fa ? 'از ${from.format(context)}' : 'From ${from.format(context)}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () async { final x=await showTimePicker(context: context, initialTime: to); if(x!=null)setState(()=>to=x); }, icon: const Icon(Icons.schedule), label: Text(widget.fa ? 'تا ${to.format(context)}' : 'To ${to.format(context)}'))),
          ]),
        ])),
        const SizedBox(height: 10),
        GlassCard(padding: EdgeInsets.zero, child: SizedBox(height: 390, child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: DemoMapPainter(dark: Theme.of(context).brightness == Brightness.dark, progress: progress))),
          Positioned(top: 12, right: 12, child: Column(children: [CircleAvatar(backgroundColor: Theme.of(context).colorScheme.surface, child: const Icon(Icons.add)), const SizedBox(height: 8), CircleAvatar(backgroundColor: Theme.of(context).colorScheme.surface, child: const Icon(Icons.remove))])),
          Positioned(bottom: 14, left: 14, right: 14, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withOpacity(.92), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.location_on, color: mtRed), const SizedBox(width: 8), Expanded(child: Text(widget.fa ? 'مسیر انتخاب‌شده • 24.8 کیلومتر • 3 توقف' : 'Selected route • 24.8 km • 3 stops'))]))),
        ]))),
        const SizedBox(height: 10),
        GlassCard(child: Column(children: [
          Slider(value: progress, onChanged: (v)=>setState(()=>progress=v), activeColor: mtRed),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: ()=>setState(()=>progress=(progress-.08).clamp(0.0,1.0).toDouble()), icon: const Icon(Icons.replay_10)),
            FilledButton.icon(onPressed: toggle, icon: Icon(playing ? Icons.pause : Icons.play_arrow), label: Text(playing ? (widget.fa ? 'توقف' : 'Pause') : (widget.fa ? 'پخش مسیر' : 'Play route'))),
            IconButton(onPressed: ()=>setState(()=>progress=(progress+.08).clamp(0.0,1.0).toDouble()), icon: const Icon(Icons.forward_10)),
          ]),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: Metric(label: widget.fa ? 'مسافت' : 'Distance', value: '24.8 km', icon: Icons.route)), Expanded(child: Metric(label: widget.fa ? 'توقف' : 'Stops', value: '3', icon: Icons.pause_circle_outline)), Expanded(child: Metric(label: widget.fa ? 'بیشترین سرعت' : 'Max speed', value: '72', icon: Icons.speed))]),
        ])),
      ],
    );
  }
}

class AlertsPage extends StatelessWidget {
  final bool fa;
  final bool armed;
  final bool siren;
  final VoidCallback onArm;
  final VoidCallback onSiren;
  const AlertsPage({super.key, required this.fa, required this.armed, required this.siren, required this.onArm, required this.onSiren});
  @override
  Widget build(BuildContext context) {
    final alerts = [
      (Icons.power_off, fa ? 'قطع برق اصلی خودرو' : 'External power disconnected', fa ? 'امروز 14:21' : 'Today 14:21', Colors.orange),
      (Icons.vibration, fa ? 'ضربه / لرزش' : 'Shock detected', fa ? 'دیروز 22:04' : 'Yesterday 22:04', mtRed),
      (Icons.key, fa ? 'ACC روشن شد' : 'ACC turned on', fa ? 'دیروز 08:10' : 'Yesterday 08:10', Colors.blue),
      (Icons.door_front_door, fa ? 'درب خودرو باز شد' : 'Door opened', fa ? '2 روز پیش' : '2 days ago', mtRed),
      (Icons.sos, 'SOS', fa ? 'آزمایشی' : 'Demo', mtRed),
    ];
    return ListView(padding: const EdgeInsets.all(14), children: [
      Row(children: [Expanded(child: FilledButton.tonalIcon(onPressed: onArm, icon: Icon(armed ? Icons.shield : Icons.shield_outlined), label: Text(armed ? (fa ? 'محافظت فعال' : 'Armed') : (fa ? 'محافظت غیرفعال' : 'Disarmed')))), const SizedBox(width: 8), Expanded(child: FilledButton.tonalIcon(onPressed: onSiren, icon: Icon(siren ? Icons.volume_up : Icons.campaign_outlined), label: Text(fa ? 'آژیر خودرو' : 'Car siren')))]),
      const SizedBox(height: 14),
      SectionTitle(title: fa ? 'هشدارها و رویدادها' : 'Alerts & events'),
      const SizedBox(height: 8),
      ...alerts.map((a)=>Padding(padding: const EdgeInsets.only(bottom: 8), child: GlassCard(child: Row(children:[CircleAvatar(backgroundColor:a.$4.withOpacity(.12), child:Icon(a.$1,color:a.$4)), const SizedBox(width:12), Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a.$2,style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(a.$3,style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant,fontSize:12))])), const Icon(Icons.chevron_left)])))),
      const SizedBox(height: 10),
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(fa ? 'هشدارهای فوری' : 'Critical alerts', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 10),
        Text(fa ? 'Door • ACC • Movement • Shock • Power Cut • Low Battery • SOS • Tamper' : 'Door • ACC • Movement • Shock • Power Cut • Low Battery • SOS • Tamper'),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: ()=>toast(context, fa ? 'آزمون اعلان بحرانی اجرا شد.' : 'Critical alert test.'), icon: const Icon(Icons.notifications_active), label: Text(fa ? 'تست هشدار بحرانی' : 'Test critical alert')),
      ])),
    ]);
  }
}

class SupportPage extends StatefulWidget {
  final bool fa;
  const SupportPage({super.key, required this.fa});
  @override
  State<SupportPage> createState()=>_SupportPageState();
}
class _SupportPageState extends State<SupportPage> {
  final msg = TextEditingController();
  final List<(bool,String,String)> chat = [(false,'سلام، وضعیت دستگاه من آفلاین شده.','10:14'),(true,'سلام. لطفاً برق خودرو و سیم‌کارت دستگاه را بررسی کنید.','10:20')];
  @override void dispose(){msg.dispose();super.dispose();}
  @override Widget build(BuildContext context){return ListView(padding:const EdgeInsets.all(14),children:[
    SectionTitle(title: widget.fa?'پشتیبانی MTcar':'MTcar Support'),const SizedBox(height:8),
    Row(children:[Expanded(child:QuickSupport(icon:Icons.chat_bubble_outline,title:widget.fa?'تیکت پشتیبانی':'Support ticket',onTap:()=>{})),const SizedBox(width:8),Expanded(child:QuickSupport(icon:Icons.call_outlined,title:widget.fa?'تماس':'Contact',onTap:()=>NativeBridge.openUrl('tel:')))]),
    const SizedBox(height:12),GlassCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[const Icon(Icons.confirmation_number_outlined,color:mtRed),const SizedBox(width:8),Text(widget.fa?'تیکت #1842':'Ticket #1842',style:const TextStyle(fontWeight:FontWeight.w900)),const Spacer(),Chip(label:Text(widget.fa?'پاسخ داده شده':'Answered'))]),
      const SizedBox(height:8),...chat.map((m)=>Align(alignment:m.$1?Alignment.centerLeft:Alignment.centerRight,child:Container(margin:const EdgeInsets.symmetric(vertical:4),padding:const EdgeInsets.all(12),constraints:const BoxConstraints(maxWidth:320),decoration:BoxDecoration(color:m.$1?const Color(0xFF173322):mtRed.withOpacity(.10),borderRadius:BorderRadius.circular(16)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(m.$2),const SizedBox(height:5),Text(m.$3,style:TextStyle(fontSize:11,color:Theme.of(context).colorScheme.onSurfaceVariant))])))),
      const SizedBox(height:10),TextField(controller:msg,maxLines:3,decoration:InputDecoration(hintText:widget.fa?'پیام جدید...':'New message...')),
      const SizedBox(height:8),FilledButton.icon(onPressed:(){if(msg.text.trim().isEmpty)return;setState((){chat.add((false,msg.text.trim(),'الان'));msg.clear();});},icon:const Icon(Icons.send),label:Text(widget.fa?'ارسال پیام':'Send')),
    ])),
    const SizedBox(height:12),GlassCard(child:Column(children:[
      ListTile(leading:const Icon(Icons.help_outline,color:mtRed),title:Text(widget.fa?'سوالات متداول':'FAQ'),trailing:const Icon(Icons.chevron_left)),
      const Divider(height:1),ListTile(leading:const Icon(Icons.email_outlined,color:mtRed),title:const Text('support@mediatelecom.ir')),
      const Divider(height:1),ListTile(leading:const Icon(Icons.info_outline,color:mtRed),title:Text(widget.fa?'درباره MTcar':'About MTcar'),subtitle:Text(widget.fa?'سامانه امنیت و رهگیری هوشمند وسیله نقلیه':'Smart vehicle tracking and security')),
    ])),
  ]);}
}

class AccountPage extends StatelessWidget {
  final bool fa;
  final bool dark;
  final VoidCallback onTheme;
  final VoidCallback onLanguage;
  const AccountPage({super.key, required this.fa, required this.dark, required this.onTheme, required this.onLanguage});
  @override Widget build(BuildContext context){return ListView(padding:const EdgeInsets.all(14),children:[
    GlassCard(child:Row(children:[const CircleAvatar(radius:28,backgroundColor:mtRed,child:Icon(Icons.person,color:Colors.white,size:30)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(fa?'کاربر MTcar':'MTcar User',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:18)),const SizedBox(height:4),const Text('0912•••••42')])),const Icon(Icons.verified,color:Color(0xFF1C9B54))])),
    const SizedBox(height:12),
    SettingsTile(icon:Icons.devices_other,title:fa?'تنظیمات دستگاه':'Device settings',subtitle:fa?'نوع دستگاه، IMEI، سیم‌کارت، اپراتور و وضعیت':'Model, IMEI, SIM, operator & status',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Directionality(textDirection:fa?TextDirection.rtl:TextDirection.ltr,child:DeviceSettingsPage(fa:fa))))),
    SettingsTile(icon:Icons.sim_card_outlined,title:fa?'سیم‌کارت دستگاه':'Device SIM',subtitle:fa?'شارژ اصلی، اینترنت، خرید بسته و استعلام':'Balance, data, packages & query',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Directionality(textDirection:fa?TextDirection.rtl:TextDirection.ltr,child:SimManagementPage(fa:fa))))),
    SettingsTile(icon:Icons.workspace_premium_outlined,title:fa?'اشتراک و پرداخت':'Subscription & billing',subtitle:fa?'247 روز باقی‌مانده':'247 days remaining',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Directionality(textDirection:fa?TextDirection.rtl:TextDirection.ltr,child:SubscriptionPage(fa:fa))))),
    SettingsTile(icon:Icons.phone_android,title:fa?'تغییر شماره موبایل':'Change mobile number',subtitle:'0912•••••42',onTap:()=>showSimpleForm(context,fa?'تغییر شماره موبایل':'Change mobile number',[fa?'رمز فعلی':'Current password',fa?'شماره جدید':'New mobile',fa?'کد تایید':'OTP'])),
    SettingsTile(icon:Icons.password,title:fa?'تغییر رمز ورود':'Change password',subtitle:fa?'رمز حساب کاربری MTcar':'MTcar account password',onTap:()=>showSimpleForm(context,fa?'تغییر رمز ورود':'Change password',[fa?'رمز فعلی':'Current password',fa?'رمز جدید':'New password',fa?'تکرار رمز جدید':'Confirm password'])),
    SettingsTile(icon:dark?Icons.light_mode:Icons.dark_mode,title:fa?'حالت نمایش':'Appearance',subtitle:dark?(fa?'تاریک':'Dark'):(fa?'روشن':'Light'),onTap:onTheme),
    SettingsTile(icon:Icons.language,title:fa?'زبان':'Language',subtitle:fa?'فارسی / English':'English / فارسی',onTap:onLanguage),
    SettingsTile(icon:Icons.receipt_long_outlined,title:fa?'تاریخچه پرداخت‌ها':'Payment history',subtitle:fa?'رسید و تمدیدها':'Receipts & renewals',onTap:()=>{}),
  ]);}
}

class DeviceSettingsPage extends StatelessWidget {
  final bool fa;
  const DeviceSettingsPage({super.key,required this.fa});
  @override Widget build(BuildContext context){return Scaffold(appBar:AppBar(title:Text(fa?'تنظیمات دستگاه':'Device settings')),body:ListView(padding:const EdgeInsets.all(14),children:[
    GlassCard(child:Column(children:[
      InfoRow(label:fa?'نوع دستگاه':'Device model',value:'MT120'),
      const InfoRow(label:'IMEI',value:'123456789012345'),
      InfoRow(label:fa?'شماره سیم‌کارت دستگاه':'Tracker SIM',value:'0919•••••81'),
      InfoRow(label:fa?'اپراتور سیم‌کارت':'SIM operator',value:fa?'همراه اول':'MCI'),
      InfoRow(label:fa?'نوع سیم‌کارت':'SIM type',value:fa?'اعتباری':'Prepaid'),
      InfoRow(label:fa?'وضعیت دستگاه':'Device status',value:fa?'آنلاین':'Online',good:true),
    ])),const SizedBox(height:12),
    GlassCard(child:Column(children:[
      const InfoRow(label:'GPS',value:'9 Satellites',good:true),const InfoRow(label:'GSM',value:'Good',good:true),
      InfoRow(label:fa?'باتری داخلی':'Backup battery',value:'87%',good:true),InfoRow(label:fa?'برق خودرو':'Vehicle power',value:'ON',good:true),
      InfoRow(label:'ACC',value:'OFF',good:true),InfoRow(label:fa?'درب خودرو':'Door',value:'Closed',good:true),
    ])),const SizedBox(height:12),
    FilledButton.icon(onPressed:()=>toast(context,fa?'درخواست بررسی وضعیت دستگاه ارسال شد.':'Device status request sent.'),icon:const Icon(Icons.refresh),label:Text(fa?'استعلام وضعیت دستگاه':'Refresh device status')),
    const SizedBox(height:8),OutlinedButton.icon(onPressed:()=>showSimpleForm(context,fa?'ویرایش اطلاعات دستگاه':'Edit device info',[fa?'نوع دستگاه':'Device model','IMEI',fa?'شماره سیم‌کارت':'SIM number',fa?'اپراتور':'Operator']),icon:const Icon(Icons.edit_outlined),label:Text(fa?'ویرایش اطلاعات':'Edit information')),
  ]));}
}

class SimManagementPage extends StatelessWidget {
  final bool fa;
  const SimManagementPage({super.key,required this.fa});
  @override Widget build(BuildContext context){return Scaffold(appBar:AppBar(title:Text(fa?'سیم‌کارت دستگاه':'Device SIM')),body:ListView(padding:const EdgeInsets.all(14),children:[
    GlassCard(child:Column(children:[
      InfoRow(label:fa?'اپراتور':'Operator',value:fa?'همراه اول':'MCI'),
      InfoRow(label:fa?'وضعیت سیم‌کارت':'SIM status',value:fa?'فعال':'Active',good:true),
      InfoRow(label:fa?'شارژ اصلی':'Main balance',value:fa?'در دسترس نیست':'Unavailable'),
      InfoRow(label:fa?'اینترنت باقی‌مانده':'Remaining data',value:fa?'در دسترس نیست':'Unavailable'),
      InfoRow(label:fa?'بسته فعال':'Active package',value:'—'),
      InfoRow(label:fa?'آخرین استعلام':'Last query',value:'—'),
    ])),const SizedBox(height:12),
    FilledButton.icon(onPressed:()=>toast(context,fa?'استعلام واقعی پس از اتصال Provider نمایش داده می‌شود.':'Real value will show after provider integration.'),icon:const Icon(Icons.refresh),label:Text(fa?'استعلام مجدد':'Refresh')),
    const SizedBox(height:8),OutlinedButton.icon(onPressed:()=>showAmountDialog(context,fa,true),icon:const Icon(Icons.account_balance_wallet_outlined),label:Text(fa?'شارژ اصلی سیم‌کارت':'Top up SIM')),
    const SizedBox(height:8),OutlinedButton.icon(onPressed:()=>showPackages(context,fa),icon:const Icon(Icons.public),label:Text(fa?'خرید بسته اینترنت':'Buy internet package')),
    const SizedBox(height:12),
    GlassCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(fa?'کدهای اپراتور (مرجع)':'Operator USSD reference',style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:8),
      const InfoRow(label:'MCI Balance',value:'*10*121#'),const InfoRow(label:'MCI Internet',value:'*100*1#'),const InfoRow(label:'MCI Packages',value:'*100#'),
      const InfoRow(label:'Irancell Balance',value:'*555*1*2#'),const InfoRow(label:'Irancell Internet',value:'*555*1*4#'),const InfoRow(label:'Irancell Packages',value:'*555*5#'),
      const SizedBox(height:8),Text(fa?'MTcar عدد ساختگی برای موجودی نشان نمی‌دهد. خرید واقعی روی شماره سیم‌کارت ردیاب از Backend انجام می‌شود.':'MTcar never fabricates balance values. Real purchases target the tracker SIM via backend.',style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant)),
    ])),
  ]));}
}

class SubscriptionPage extends StatelessWidget {
  final bool fa;
  const SubscriptionPage({super.key,required this.fa});
  @override Widget build(BuildContext context){return Scaffold(appBar:AppBar(title:Text(fa?'اشتراک و پرداخت':'Subscription & billing')),body:ListView(padding:const EdgeInsets.all(14),children:[
    GlassCard(child:Column(children:[
      Row(children:[const Icon(Icons.workspace_premium,color:mtRed,size:30),const SizedBox(width:10),Expanded(child:Text(fa?'اشتراک سالانه MTcar':'MTcar annual membership',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900))),const Chip(label:Text('ACTIVE'))]),
      const SizedBox(height:14),InfoRow(label:fa?'روزهای باقی‌مانده':'Days remaining',value:'247',good:true),InfoRow(label:fa?'اعتبار تا':'Valid until',value:'1406/06/12'),InfoRow(label:fa?'مبلغ سالانه':'Annual price',value:fa?'از سرور دریافت می‌شود':'Server controlled'),
    ])),const SizedBox(height:12),FilledButton.icon(onPressed:()=>toast(context,fa?'درگاه پرداخت پس از اتصال VPS فعال می‌شود.':'Payment gateway activates after VPS setup.'),icon:const Icon(Icons.credit_card),label:Text(fa?'تمدید / پرداخت اشتراک':'Renew / pay')),
    const SizedBox(height:12),SectionTitle(title:fa?'تاریخچه پرداخت':'Payment history'),const SizedBox(height:8),
    GlassCard(child:Column(children:[InfoRow(label:'1405/06/12',value:fa?'1,200,000 تومان':'1,200,000 Toman',good:true),InfoRow(label:'1404/06/12',value:fa?'900,000 تومان':'900,000 Toman',good:true)])),
  ]));}
}

class VoiceMonitor {
  static Future<void> start(BuildContext context, bool fa) async {
    final ok = await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(fa?'شنود آنلاین داخل خودرو':'Live vehicle audio'),content:Text(fa?'فقط برای خودروی تحت اختیار و با رعایت قوانین حریم خصوصی استفاده شود. صدا در MTcar ضبط نمی‌شود. در Monitor Mode رهگیری GPS موقتاً متوقف می‌شود.':'Use only for a vehicle you are authorized to monitor. MTcar does not record audio. GPS tracking pauses while monitor mode is active.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(fa?'انصراف':'Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(fa?'تایید و ادامه':'Continue'))]));
    if(ok!=true)return;
    try { await NativeBridge.monitorMode(); toast(context,fa?'فرمان Monitor Mode آماده شد؛ تماس با سیم‌کارت ردیاب باز می‌شود.':'Monitor mode prepared; tracker SIM dialer opens.'); } catch(_){ toast(context,fa?'در نسخه آزمایشی، فرمان شنود شبیه‌سازی شد.':'Voice monitor simulated in demo build.'); }
  }
}

class EngineSafety {
  static Future<void> confirm(BuildContext context,bool fa) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(fa?'قطع موتور':'Engine cut'),content:Text(fa?'فرمان قطع موتور فقط در سرعت ایمن مجاز است. MTcar روی سرور قطع موتور را بالاتر از 20 km/h مسدود می‌کند.':'Engine cut is only allowed at a safe speed. Server safety gate blocks it above 20 km/h.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(fa?'انصراف':'Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(fa?'ارسال فرمان':'Send command'))])); if(ok==true)toast(context,fa?'درخواست قطع موتور ثبت شد (Demo).':'Engine cut request queued (demo).');
  }
}

class NativeBridge {
  static const channel=MethodChannel('ir.mediatelecom.mtcar/native');
  static Future<void> monitorMode() async { await channel.invokeMethod('monitorMode', {'phone':'09190000000','password':'123456'}); }
  static Future<void> openUrl(String url) async { try{await channel.invokeMethod('openUrl',{'url':url});}catch(_){}}
}

class DemoMapPainter extends CustomPainter {
  final bool dark; final double progress;
  DemoMapPainter({required this.dark,required this.progress});
  @override void paint(Canvas canvas,Size size){
    final bg=Paint()..color=dark?const Color(0xFF15191F):const Color(0xFFE9EDF2); canvas.drawRect(Offset.zero&size,bg);
    final road=Paint()..color=dark?Colors.white12:Colors.white..strokeWidth=13..style=PaintingStyle.stroke..strokeCap=StrokeCap.round;
    final road2=Paint()..color=dark?Colors.white10:const Color(0xFFD3D9E1)..strokeWidth=4..style=PaintingStyle.stroke;
    for(int i=0;i<6;i++){final y=55.0+i*58; canvas.drawLine(Offset(-20,y),Offset(size.width+30,y-30),road);}
    for(int i=0;i<5;i++){final x=35.0+i*85; canvas.drawLine(Offset(x,-20),Offset(x+70,size.height+20),road2);}
    final path=Path()..moveTo(30,size.height*.78)..cubicTo(size.width*.20,size.height*.58,size.width*.38,size.height*.86,size.width*.52,size.height*.50)..cubicTo(size.width*.66,size.height*.18,size.width*.82,size.height*.30,size.width-32,size.height*.16);
    final p=Paint()..color=mtRed..strokeWidth=6..style=PaintingStyle.stroke..strokeCap=StrokeCap.round; canvas.drawPath(path,p);
    final metric=path.computeMetrics().first; final tan=metric.getTangentForOffset(metric.length*progress); if(tan!=null){canvas.drawCircle(tan.position,15,Paint()..color=Colors.white);canvas.drawCircle(tan.position,10,Paint()..color=mtRed);}
    for(final f in [.15,.48,.77]){final t=metric.getTangentForOffset(metric.length*f);if(t!=null){canvas.drawCircle(t.position,6,Paint()..color=Colors.orange);}}
  }
  @override bool shouldRepaint(covariant DemoMapPainter old)=>old.progress!=progress||old.dark!=dark;
}

class MtLogo extends StatelessWidget {
  final double size; final bool white;
  const MtLogo({super.key,required this.size,this.white=false});
  @override Widget build(BuildContext context){return Container(width:size,height:size,decoration:BoxDecoration(color:white?Colors.white.withOpacity(.16):mtRed,borderRadius:BorderRadius.circular(size*.27),boxShadow:[BoxShadow(color:mtRed.withOpacity(.22),blurRadius:18,offset:const Offset(0,6))],border:Border.all(color:white?Colors.white30:mtDarkRed.withOpacity(.18))),child:Stack(alignment:Alignment.center,children:[Icon(Icons.directions_car_filled,color:Colors.white,size:size*.52),Positioned(bottom:size*.08,child:Container(width:size*.42,height:size*.08,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20))))]));}
}

class GlassCard extends StatelessWidget {
  final Widget child; final EdgeInsetsGeometry padding;
  const GlassCard({super.key,required this.child,this.padding=const EdgeInsets.all(16)});
  @override Widget build(BuildContext context){final dark=Theme.of(context).brightness==Brightness.dark;return Container(padding:padding,decoration:BoxDecoration(color:(dark?const Color(0xFF191C21):Colors.white).withOpacity(.96),borderRadius:BorderRadius.circular(20),border:Border.all(color:dark?Colors.white12:const Color(0xFFE0E4EA)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(dark ? .20 : .05),blurRadius:18,offset:const Offset(0,6))]),child:child);}
}

class SectionTitle extends StatelessWidget {final String title;const SectionTitle({super.key,required this.title});@override Widget build(BuildContext context)=>Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900));}
class StatusCard extends StatelessWidget {final IconData icon;final String title,value;final bool good;const StatusCard({super.key,required this.icon,required this.title,required this.value,required this.good});@override Widget build(BuildContext context)=>GlassCard(child:Row(children:[Icon(icon,color:good?const Color(0xFF1C9B54):mtRed),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),Text(value,style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant,fontSize:12))]))]));}
class Metric extends StatelessWidget {final String label,value;final IconData icon;const Metric({super.key,required this.label,required this.value,required this.icon});@override Widget build(BuildContext context)=>Column(children:[Icon(icon,color:mtRed),const SizedBox(height:5),Text(value,style:const TextStyle(fontWeight:FontWeight.w900)),Text(label,textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:Theme.of(context).colorScheme.onSurfaceVariant))]);}
class QuickAction extends StatelessWidget {final IconData icon;final String label;final VoidCallback onTap;final bool danger,active;const QuickAction({super.key,required this.icon,required this.label,required this.onTap,this.danger=false,this.active=false});@override Widget build(BuildContext context)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:danger?mtRed.withOpacity(.09):active?const Color(0xFF1C9B54).withOpacity(.10):Theme.of(context).colorScheme.surface,borderRadius:BorderRadius.circular(18),border:Border.all(color:danger?mtRed.withOpacity(.25):active?const Color(0xFF1C9B54).withOpacity(.25):Theme.of(context).dividerColor)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:danger?mtRed:active?const Color(0xFF1C9B54):Theme.of(context).colorScheme.onSurface),const SizedBox(height:7),Text(label,textAlign:TextAlign.center,maxLines:2,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700))])));}
class StatusRow extends StatelessWidget {final IconData icon;final String title,value;final bool good;const StatusRow({super.key,required this.icon,required this.title,required this.value,required this.good});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Row(children:[Icon(icon,color:good?const Color(0xFF1C9B54):mtRed),const SizedBox(width:10),Expanded(child:Text(title)),Text(value,style:TextStyle(fontWeight:FontWeight.w800,color:good?const Color(0xFF1C9B54):mtRed))]));}
class SettingsTile extends StatelessWidget {final IconData icon;final String title,subtitle;final VoidCallback onTap;const SettingsTile({super.key,required this.icon,required this.title,required this.subtitle,required this.onTap});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:8),child:GlassCard(padding:EdgeInsets.zero,child:ListTile(onTap:onTap,leading:CircleAvatar(backgroundColor:mtRed.withOpacity(.09),child:Icon(icon,color:mtRed)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(subtitle),trailing:const Icon(Icons.chevron_left))));}
class InfoRow extends StatelessWidget {final String label,value;final bool good;const InfoRow({super.key,required this.label,required this.value,this.good=false});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Row(children:[Expanded(child:Text(label,style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant))),Text(value,style:TextStyle(fontWeight:FontWeight.w800,color:good?const Color(0xFF1C9B54):null))]));}
class QuickSupport extends StatelessWidget {final IconData icon;final String title;final VoidCallback onTap;const QuickSupport({super.key,required this.icon,required this.title,required this.onTap});@override Widget build(BuildContext context)=>GlassCard(child:InkWell(onTap:onTap,child:Column(children:[Icon(icon,color:mtRed,size:30),const SizedBox(height:8),Text(title,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w800))])));}

void toast(BuildContext context,String text){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text),behavior:SnackBarBehavior.floating));}

Future<void> showSimpleForm(BuildContext context,String title,List<String> fields) async {final cs=fields.map((_)=>TextEditingController()).toList();await showDialog(context:context,builder:(c)=>AlertDialog(title:Text(title),content:SizedBox(width:360,child:Column(mainAxisSize:MainAxisSize.min,children:[for(int i=0;i<fields.length;i++)Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:cs[i],obscureText:fields[i].contains('رمز')||fields[i].toLowerCase().contains('password'),decoration:InputDecoration(labelText:fields[i])))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('انصراف')),FilledButton(onPressed:(){Navigator.pop(c);toast(context,'ذخیره شد (Demo)');},child:const Text('ذخیره'))]));for(final x in cs)x.dispose();}
Future<void> showAmountDialog(BuildContext context,bool fa,bool topup) async {final c=TextEditingController(text:'500000');await showDialog(context:context,builder:(x)=>AlertDialog(title:Text(fa?'شارژ سیم‌کارت':'SIM top-up'),content:TextField(controller:c,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:fa?'مبلغ به ریال':'Amount (Rial)')),actions:[TextButton(onPressed:()=>Navigator.pop(x),child:Text(fa?'انصراف':'Cancel')),FilledButton(onPressed:(){Navigator.pop(x);toast(context,fa?'خرید واقعی پس از اتصال API شارژ انجام می‌شود.':'Real top-up requires provider API.');},child:Text(fa?'ادامه پرداخت':'Continue'))]));c.dispose();}
Future<void> showPackages(BuildContext context,bool fa) async {await showModalBottomSheet(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:Padding(padding:const EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(fa?'بسته‌های اینترنت':'Internet packages',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:12),for(final p in ['500 MB • 30 روز','1 GB • 30 روز','2 GB • 60 روز'])ListTile(leading:const Icon(Icons.public,color:mtRed),title:Text(p),trailing:FilledButton(onPressed:(){Navigator.pop(c);toast(context,fa?'لیست واقعی بسته‌ها از Provider دریافت می‌شود.':'Real packages come from provider.');},child:Text(fa?'خرید':'Buy')))]))));}
