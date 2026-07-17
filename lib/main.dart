import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:doctor_app/constants.dart';
import 'package:doctor_app/core/service_locator.dart';
import 'package:doctor_app/model.dart/app_version_model.dart';
import 'package:doctor_app/presentation/auth/login_screen.dart';
import 'package:doctor_app/presentation/doctor_app.dart';
import 'package:doctor_app/size_confige.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: Services.I.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'CAREGO',
      theme: ThemeData(
        fontFamily: "Nunito",
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Builder(builder: (context) {
        SizeConfig.initSize(context);
        return const AppLaunchScreen();
      }),
    );
  }
}

class AppLaunchScreen extends StatefulWidget {
  const AppLaunchScreen({Key? key}) : super(key: key);

  @override
  State<AppLaunchScreen> createState() => _AppLaunchScreenState();
}

class _AppLaunchScreenState extends State<AppLaunchScreen> {
  static const String _currentVersion = '1.0.0';
  bool _showHome = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _setupSessionExpiredHandler();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppVersion();
    });
  }

  void _setupSessionExpiredHandler() {
    Services.I.onSessionExpired = () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    };
  }

  Future<void> _checkAppVersion() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    const version = AppVersionModel(
      latestVersion: '1.1.0',
      downloadUrl: 'https://carego.app/download',
      releaseNotes:
          'Versi terbaru CAREGO membawa fitur Chat dan penyewaan alat kesehatan.',
      forceUpdate: false,
    );

    if (_isNewerVersion(version.latestVersion, _currentVersion)) {
      _showUpdateDialog(version);
      return;
    }

    await _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await Services.I.auth.me();
    if (session != null) await _registerStoredFcmToken();
    if (!mounted) return;
    setState(() {
      _isAuthenticated = session != null;
      _showHome = true;
    });
  }

  Future<void> _registerStoredFcmToken() async {
    final token = await Services.I.tokens.readFcm();
    if (token == null || token.isEmpty) return;
    try {
      await Services.I.notifications.registerDevice(
        fcmToken: token,
        platform: _platformName(),
      );
    } catch (_) {
      // Best-effort: push registration must not block app launch.
    }
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'unknown';
    }
  }

  bool _isNewerVersion(String latestVersion, String currentVersion) {
    final latest = latestVersion.split('.').map(int.parse).toList();
    final current = currentVersion.split('.').map(int.parse).toList();
    final maxLength =
        latest.length > current.length ? latest.length : current.length;

    for (var i = 0; i < maxLength; i++) {
      final latestPart = i < latest.length ? latest[i] : 0;
      final currentPart = i < current.length ? current[i] : 0;
      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }

    return false;
  }

  void _showUpdateDialog(AppVersionModel version) {
    showDialog(
      context: context,
      barrierDismissible: !version.forceUpdate,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pembaruan Tersedia'),
          content: Text(
            'Versi terbaru: ${version.latestVersion}\n\n${version.releaseNotes}',
          ),
          actions: [
            if (!version.forceUpdate)
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _checkSession();
                },
                child: const Text('Nanti Saja'),
              ),
            ElevatedButton(
              onPressed: () async {
                if (!version.forceUpdate) {
                  Navigator.of(dialogContext).pop();
                  await _checkSession();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Membuka halaman update aplikasi...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0D9488),
              ),
              child: const Text(
                'Update Sekarang',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showHome) {
      return _isAuthenticated ? DoctorScreen() : const LoginScreen();
    }

    return const Scaffold(
      backgroundColor: kBackgroundColor,
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xff0D9488),
        ),
      ),
    );
  }
}
