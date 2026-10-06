import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../models/download_item.dart';
import '../services/download_service.dart';
import '../utils/format_utils.dart';
import '../widgets/glass_card.dart';
import 'player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  String sort = 'date';

  List<DownloadItem> _sortItems(List<DownloadItem> items) {
    final list = List<DownloadItem>.from(items);
    switch (sort) {
      case 'name':
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'size':
        list.sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
        break;
      case 'status':
        list.sort((a, b) => a.status.index.compareTo(b.status.index));
        break;
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  Future<void> _open(DownloadItem item) async {
    final file = File(item.filePath);
    if (!await file.exists()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الملف غير موجود على الجهاز.')));
      return;
    }
    final path = item.filePath.toLowerCase();
    if (['.mp4', '.mkv', '.webm', '.mov', '.m4v'].any(path.endsWith)) {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(path: item.filePath, title: item.title)));
    } else {
      await OpenFilex.open(item.filePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DownloadService>();
    final items = _sortItems(service.items);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التنزيلات'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => setState(() => sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'date', child: Text('الأحدث')),
              PopupMenuItem(value: 'name', child: Text('الاسم')),
              PopupMenuItem(value: 'size', child: Text('الحجم')),
              PopupMenuItem(value: 'status', child: Text('الحالة')),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('لسه مفيش تحميلات'))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: items.length,
              itemBuilder: (_, i) => _DownloadCard(item: items[i], service: service, onOpen: () => _open(items[i])),
            ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  final DownloadItem item;
  final DownloadService service;
  final VoidCallback onOpen;
  const _DownloadCard({required this.item, required this.service, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final active = item.status == DownloadStatus.downloading;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.video_file, size: 38),
              const SizedBox(width: 12),
              Expanded(child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: item.progress),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(service.progressText(item), style: Theme.of(context).textTheme.bodySmall)),
              if (active) Text(FormatUtils.speed(item.speed), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          if (item.error != null) Text(item.error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          Row(
            children: [
              if (active) IconButton(onPressed: () => service.pause(item.id), icon: const Icon(Icons.pause)),
              if (item.status == DownloadStatus.paused || item.status == DownloadStatus.queued || item.status == DownloadStatus.failed)
                IconButton(
                  onPressed: () => item.status == DownloadStatus.failed ? service.retry(item.id) : service.resume(item.id),
                  icon: Icon(item.status == DownloadStatus.failed ? Icons.refresh : Icons.play_arrow),
                ),
              if (item.status == DownloadStatus.completed) IconButton(onPressed: onOpen, icon: const Icon(Icons.play_circle_fill)),
              IconButton(onPressed: () => service.cancel(item.id), icon: const Icon(Icons.close)),
              const Spacer(),
              IconButton(onPressed: () => service.delete(item.id), icon: const Icon(Icons.delete_outline)),
            ],
          ),
        ],
      ),
    );
  }
}
