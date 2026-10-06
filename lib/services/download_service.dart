import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/download_item.dart';
import '../utils/format_utils.dart';
import 'storage_service.dart';
import 'web_extractor_service.dart';

class DownloadService extends ChangeNotifier {
  final Dio _dio = Dio();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final WebExtractorService extractor = WebExtractorService();
  final Map<String, List<CancelToken>> _tokens = {};
  final List<DownloadItem> _items = [];

  int maxConnections = 8;
  int concurrentDownloads = 2;

  DownloadService() { _load(); }

  List<DownloadItem> get items => List.unmodifiable(_items);

  int get activeCount => _items.where((i) => i.status == DownloadStatus.downloading).length;
  int get completedCount => _items.where((i) => i.status == DownloadStatus.completed).length;

  Future<void> initializeNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(settings);
    await _notifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  Future<void> _load() async {
    _items..clear()..addAll(StorageService.getDownloads());
    notifyListeners();
  }

  Future<DownloadItem?> addDownload(String url, {String? title}) async {
    final media = await extractor.extract(url);
    if (media == null) return null;

    final safeTitle = FormatUtils.safeFileName(title ?? media.title);
    final extension = media.extension.isEmpty ? 'mp4' : media.extension;
    final path = await StorageService.prepareFinalFile('$safeTitle.$extension');

    final item = DownloadItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: safeTitle,
      url: media.url,
      filePath: path,
      totalBytes: media.size ?? 0,
      status: DownloadStatus.queued,
    );

    _items.insert(0, item);
    await StorageService.saveDownload(item);
    notifyListeners();
    unawaited(_startNext());
    return item;
  }

  Future<void> _startNext() async {
    final available = concurrentDownloads - activeCount;
    if (available <= 0) return;

    final queue = _items.where((i) =>
      i.status == DownloadStatus.queued || i.status == DownloadStatus.paused
    ).take(available).toList();

    for (final item in queue) {
      unawaited(_download(item));
    }
  }

  Future<void> _download(DownloadItem item) async {
    item.status = DownloadStatus.downloading;
    item.error = null;
    notifyListeners();
    await StorageService.saveDownload(item);

    try {
      final lower = item.url.toLowerCase();
      if (lower.contains('.m3u8') || lower.contains('.mpd')) {
        throw Exception('روابط HLS/DASH تحتاج محرك دمج وسائط.');
      }

      if (await _supportsRanges(item.url)) {
        await _downloadMultiThreaded(item);
      } else {
        await _downloadSingle(item);
      }

      item.status = DownloadStatus.completed;
      item.progress = 1;
      item.completedAt = DateTime.now();
      await StorageService.saveDownload(item);
      await _showCompletedNotification(item);
      notifyListeners();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (item.status != DownloadStatus.cancelled) item.status = DownloadStatus.paused;
      } else {
        item.status = DownloadStatus.failed;
        item.error = e.message ?? 'حدث خطأ أثناء التحميل';
      }
      await StorageService.saveDownload(item);
      notifyListeners();
    } catch (e) {
      if (item.status != DownloadStatus.cancelled) item.status = DownloadStatus.failed;
      item.error = e.toString();
      await StorageService.saveDownload(item);
      notifyListeners();
    }

    _tokens.remove(item.id);
    unawaited(_startNext());
  }

  Future<bool> _supportsRanges(String url) async {
    try {
      final r = await _dio.head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s >= 200 && s < 400,
        ),
      );
      final ranges = r.headers.value('accept-ranges');
      final length = r.headers.value('content-length');
      return ranges?.toLowerCase() == 'bytes' && int.tryParse(length ?? '') != null;
    } catch (_) {
      return false;
    }
  }

  Future<int> _contentLength(String url) async {
    try {
      final r = await _dio.head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s >= 200 && s < 400,
        ),
      );
      return int.tryParse(r.headers.value('content-length') ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _downloadSingle(DownloadItem item) async {
    final token = CancelToken();
    _tokens[item.id] = [token];
    final tempPath = '${item.filePath}.part';
    final file = File(tempPath);
    if (await file.exists()) await file.delete();
    final started = DateTime.now();

    await _dio.download(
      item.url,
      tempPath,
      cancelToken: token,
      deleteOnError: false,
      onReceiveProgress: (received, total) {
        final elapsed = DateTime.now().difference(started).inMilliseconds;
        item.downloadedBytes = received;
        if (total > 0) {
          item.totalBytes = total;
          item.progress = received / total;
        }
        if (elapsed > 0) item.speed = received / (elapsed / 1000);
        notifyListeners();
      },
    );

    final completed = File(item.filePath);
    if (await completed.exists()) await completed.delete();
    await file.rename(item.filePath);
    item.downloadedBytes = await completed.length();
    if (item.totalBytes <= 0) item.totalBytes = item.downloadedBytes;
  }

  Future<void> _downloadMultiThreaded(DownloadItem item) async {
    final total = await _contentLength(item.url);
    if (total <= 0) return _downloadSingle(item);

    item.totalBytes = total;
    final connections = min(maxConnections, 8);
    final segmentSize = (total / connections).ceil();
    final dir = Directory('${item.filePath}.segments');
    if (!await dir.exists()) await dir.create(recursive: true);

    final tokens = <CancelToken>[];
    _tokens[item.id] = tokens;
    final progress = List<int>.filled(connections, 0);
    final started = DateTime.now();

    Future<void> segment(int index) async {
      final start = index * segmentSize;
      final end = min(total - 1, start + segmentSize - 1);
      final segmentFile = File('${dir.path}/segment_$index.part');

      var current = await segmentFile.exists() ? await segmentFile.length() : 0;
      if (current > end - start + 1) {
        await segmentFile.delete();
        current = 0;
      }

      final token = CancelToken();
      tokens.add(token);

      if (start + current > end) {
        progress[index] = end - start + 1;
        return;
      }

      final response = await _dio.get<ResponseBody>(
        item.url,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Range': 'bytes=${start + current}-$end',
            'Accept-Encoding': 'identity',
          },
        ),
      );

      final sink = segmentFile.openWrite(mode: FileMode.append);
      try {
        await for (final chunk in response.data!.stream) {
          if (item.status == DownloadStatus.paused) {
            token.cancel();
            break;
          }
          sink.add(chunk);
          current += chunk.length;
          progress[index] = current;
          final done = progress.fold<int>(0, (a, b) => a + b);
          final elapsed = DateTime.now().difference(started).inMilliseconds;
          item.downloadedBytes = done;
          item.progress = done / total;
          if (elapsed > 0) item.speed = done / (elapsed / 1000);
          notifyListeners();
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    }

    await Future.wait(List.generate(connections, segment));

    if (item.status == DownloadStatus.paused) return;

    final output = File(item.filePath);
    if (await output.exists()) await output.delete();
    final sink = output.openWrite();

    try {
      for (var i = 0; i < connections; i++) {
        final segmentFile = File('${dir.path}/segment_$i.part');
        if (await segmentFile.exists()) {
          await sink.addStream(segmentFile.openRead());
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    if (await dir.exists()) await dir.delete(recursive: true);
    item.downloadedBytes = total;
    item.progress = 1;
  }

  Future<void> pause(String id) async {
    final item = _find(id);
    if (item == null) return;
    item.status = DownloadStatus.paused;
    _tokens[id]?.forEach((t) => t.cancel());
    await StorageService.saveDownload(item);
    notifyListeners();
  }

  Future<void> resume(String id) async {
    final item = _find(id);
    if (item == null) return;
    item.status = DownloadStatus.queued;
    item.error = null;
    await StorageService.saveDownload(item);
    notifyListeners();
    unawaited(_startNext());
  }

  Future<void> cancel(String id) async {
    final item = _find(id);
    if (item == null) return;
    item.status = DownloadStatus.cancelled;
    _tokens[id]?.forEach((t) => t.cancel());
    await StorageService.saveDownload(item);
    notifyListeners();
    unawaited(_startNext());
  }

  Future<void> retry(String id) async {
    final item = _find(id);
    if (item == null) return;
    item.status = DownloadStatus.queued;
    item.error = null;
    await StorageService.saveDownload(item);
    notifyListeners();
    unawaited(_startNext());
  }

  Future<void> delete(String id) async {
    final item = _find(id);
    if (item == null) return;
    _tokens[id]?.forEach((t) => t.cancel());
    try {
      final file = File(item.filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    final dir = Directory('${item.filePath}.segments');
    if (await dir.exists()) {
      try { await dir.delete(recursive: true); } catch (_) {}
    }
    _items.remove(item);
    await StorageService.deleteDownload(id);
    notifyListeners();
  }

  DownloadItem? _find(String id) {
    try { return _items.firstWhere((i) => i.id == id); } catch (_) { return null; }
  }

  Future<void> _showCompletedNotification(DownloadItem item) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'downloads',
        'التنزيلات',
        channelDescription: 'إشعارات مدير التحميلات',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _notifications.show(item.id.hashCode, 'اكتمل التحميل', item.title, details);
  }

  String progressText(DownloadItem item) =>
      '${FormatUtils.percentage(item.progress)} • ${FormatUtils.bytes(item.downloadedBytes)} / ${FormatUtils.bytes(item.totalBytes)}';

  @override
  void dispose() {
    extractor.dispose();
    for (final tokens in _tokens.values) {
      for (final token in tokens) token.cancel();
    }
    _dio.close();
    super.dispose();
  }
}
