import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../widgets/glass_card.dart';
import 'browser_screen.dart';
import 'downloads_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  final pages = const [Dashboard(), BrowserScreen(), DownloadsScreen(), SettingsScreen()];

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final url = data?.text?.trim();
    if (url == null || !url.startsWith(RegExp(r'https?://'))) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الحافظة لا تحتوي على رابط صالح.')));
      return;
    }
    final item = await context.read<DownloadService>().addDownload(url);
    if (!mounted) return;
    setState(() => index = 2);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(item == null ? 'لم أستطع استخراج فيديو من الرابط.' : 'بدأ تحميل ${item.title}')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: index, children: pages),
    floatingActionButton: index == 0 ? FloatingActionButton.extended(onPressed: _paste, icon: const Icon(Icons.content_paste), label: const Text('تحميل من الحافظة')) : null,
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (v) => setState(() => index = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.language_outlined), selectedIcon: Icon(Icons.language), label: 'المتصفح'),
        NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: 'التنزيلات'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
      ],
    ),
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DownloadService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Download Manager')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مدير تحميلاتك، بس على أصوله 😎', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('نزّل الملفات، راقب السرعة، وشغّل الفيديوهات من مكان واحد.'),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: () {
                final state = context.findAncestorStateOfType<_HomeScreenState>();
                state?.setState(() => state.index = 1);
              }, icon: const Icon(Icons.language), label: const Text('فتح المتصفح')),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Stat(title: 'جاري', value: '${service.activeCount}', icon: Icons.downloading)),
            const SizedBox(width: 12),
            Expanded(child: _Stat(title: 'مكتمل', value: '${service.completedCount}', icon: Icons.check_circle)),
          ]),
          const SizedBox(height: 16),
          const GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('طريقة سريعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 12),
            Text('• انسخ رابط فيديو ثم استخدم زر تحميل من الحافظة.'),
            SizedBox(height: 8),
            Text('• أو افتح الموقع من المتصفح الداخلي وشغّل الفيديو.'),
            SizedBox(height: 8),
            Text('• الروابط المباشرة التي تدعم Range يمكن تقسيمها إلى 8 أجزاء.'),
          ])),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const _Stat({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(children: [
      Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      Text(title),
    ]),
  );
}
