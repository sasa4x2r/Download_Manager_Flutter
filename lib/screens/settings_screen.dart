import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/download_service.dart';
import '../services/storage_service.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  int connections = 8;
  int concurrent = 2;
  String? safUri;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      notifications = prefs.getBool('notifications') ?? true;
      connections = prefs.getInt('connections') ?? 8;
      concurrent = prefs.getInt('concurrent') ?? 2;
      safUri = prefs.getString('saf_uri');
    });
    final service = context.read<DownloadService>();
    service.maxConnections = connections;
    service.concurrentDownloads = concurrent;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', notifications);
    await prefs.setInt('connections', connections);
    await prefs.setInt('concurrent', concurrent);
    final service = context.read<DownloadService>();
    service.maxConnections = connections;
    service.concurrentDownloads = concurrent;
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
  }

  Future<void> _chooseFolder() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختيار مجلد SAF يحتاج ربطًا إضافيًا حسب إصدار Android في مشروعك.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الإعدادات')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('التحميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
              const SizedBox(height: 16),
              Text('الاتصالات لكل ملف: $connections'),
              Slider(value: connections.toDouble(), min: 1, max: 8, divisions: 7, label: '$connections', onChanged: (v) => setState(() => connections = v.round())),
              Text('عدد التحميلات في نفس الوقت: $concurrent'),
              Slider(value: concurrent.toDouble(), min: 1, max: 5, divisions: 4, label: '$concurrent', onChanged: (v) => setState(() => concurrent = v.round())),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: notifications,
            onChanged: (v) => setState(() => notifications = v),
            title: const Text('الإشعارات'),
            subtitle: const Text('إظهار إشعارات اكتمال التحميلات'),
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مجلد التحميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(safUri == null ? 'المجلد الداخلي للتطبيق' : 'تم اختيار مجلد خارجي'),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _chooseFolder, icon: const Icon(Icons.folder_open), label: const Text('اختيار مجلد')),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: const Text('الوضع الداكن والفاتح يتبعان إعدادات الجهاز تلقائيًا.'),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('حفظ الإعدادات')),
      ],
    ),
  );
}
