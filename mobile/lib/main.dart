import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_config.dart';
import 'app/mtcar_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF970006),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(MtCarApp(prefs: prefs));
}

class MtCarApp extends StatefulWidget {
  final SharedPreferences prefs;

  const MtCarApp({super.key, required this.prefs});

  @override
  State<MtCarApp> createState() => _MtCarAppState();
}

class _MtCarAppState extends State<MtCarApp> {
  late String? token;
  late bool darkMode;
  late bool onboardingDone;
  bool showAuth = false;

  @override
  void initState() {
    super.initState();
    token = widget.prefs.getString('mtcar_auth_token');
    darkMode = widget.prefs.getBool('mtcar_dark_mode') ?? false;
    onboardingDone = widget.prefs.getBool('mtcar_onboarding_done') ?? false;
  }

  Future<void> _authenticated(String value, bool remember) async {
    if (remember) {
      await widget.prefs.setString('mtcar_auth_token', value);
    } else {
      await widget.prefs.remove('mtcar_auth_token');
    }
    await widget.prefs.setBool('mtcar_onboarding_done', true);
    if (!mounted) return;
    setState(() {
      token = value;
      onboardingDone = true;
      showAuth = false;
    });
  }

  Future<void> _logout() async {
    await widget.prefs.remove('mtcar_auth_token');
    if (!mounted) return;
    setState(() {
      token = null;
      showAuth = true;
    });
  }

  Future<void> _toggleTheme() async {
    final value = !darkMode;
    await widget.prefs.setBool('mtcar_dark_mode', value);
    if (!mounted) return;
    setState(() => darkMode = value);
  }

  Future<void> _startOnboarding() async {
    // Account creation no longer depends on SMS/phone permissions.
    // Optional tracker SMS Backup permissions are requested only if the user
    // explicitly enables that feature while adding a device.
    await widget.prefs.setBool('mtcar_onboarding_done', true);
    if (!mounted) return;
    setState(() {
      onboardingDone = true;
      showAuth = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget home;

    if (token != null) {
      home = MainShell(
        baseUrl: AppConfig.apiBaseUrl,
        token: token!,
        darkMode: darkMode,
        onToggleTheme: _toggleTheme,
        onLogout: _logout,
      );
    } else if (!onboardingDone && !showAuth) {
      home = WelcomeScreen(
        darkMode: darkMode,
        onTheme: _toggleTheme,
        onStart: _startOnboarding,
        onLogin: () => setState(() => showAuth = true),
      );
    } else {
      home = AuthScreen(
        baseUrl: AppConfig.apiBaseUrl,
        darkMode: darkMode,
        onTheme: _toggleTheme,
        onAuthenticated: _authenticated,
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MTcar',
      theme: mtLightTheme(),
      darkTheme: mtDarkTheme(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: home,
    );
  }
}
