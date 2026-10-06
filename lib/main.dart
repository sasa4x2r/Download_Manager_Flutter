import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/download_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await _initializeBackgroundService();

  final service = DownloadService();
  await service.initializeNotifications();
  await _requestPermissions();

  runApp(ChangeNotifierProvider.value(
    value: service,
    child: const DownloadManagerApp(),
  ));
}

Future<void> _requestPermissions() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

Future<void> _initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: backgroundServiceEntryPoint,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      initialNotificationTitle: 'Download Manager',
      initialNotificationContent: 'مدير التحميلات جاهز',
      notificationChannelId: 'download_manager_service',
      foregroundServiceNotificationId: 9001,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: backgroundServiceEntryPoint,
      onBackground: iosBackgroundService,
    ),
  );
}

@pragma('vm:entry-point')
void backgroundServiceEntryPoint(ServiceInstance service) {
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((_) => service.stopSelf());
  }
  Timer.periodic(const Duration(seconds: 10), (_) {
    service.invoke('heartbeat', {'timestamp': DateTime.now().toIso8601String()});
  });
}

@pragma('vm:entry-point')
Future<bool> iosBackgroundService(ServiceInstance service) async {
  service.invoke('heartbeat', {'timestamp': DateTime.now().toIso8601String()});
  return true;
}

class DownloadManagerApp extends StatelessWidget {
  const DownloadManagerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Download Manager',
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: ThemeMode.system,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: const HomeScreen(),
  );
}