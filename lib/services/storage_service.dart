import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';

class StorageService {
  static const downloadsBox = 'downloads';
  static const settingsBox = 'settings';
  static late Box downloads;

  static Future<void> init() async {
    await Hive.initFlutter();
    downloads = await Hive.openBox(downloadsBox);
    await Hive.openBox(settingsBox);
  }

  static Future<void> saveDownload(DownloadItem item) async =>
      downloads.put(item.id, item.toMap());

  static Future<void> deleteDownload(String id) async =>
      downloads.delete(id);

  static List<DownloadItem> getDownloads() => downloads.values
      .map((v) => DownloadItem.fromMap(Map<String, dynamic>.from(v as Map)))
      .toList();

  static Future<Directory> getLocalDownloadDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/Downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> prepareFinalFile(String fileName) async {
    final directory = await getLocalDownloadDirectory();
    return '${directory.path}/$fileName';
  }

  static Future<String?> getSafUri() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('saf_uri');
  }

  static Future<void> setSafUri(String? uri) async {
    final prefs = await SharedPreferences.getInstance();
    if (uri == null || uri.isEmpty) {
      await prefs.remove('saf_uri');
    } else {
      await prefs.setString('saf_uri', uri);
    }
  }

  static Future<List<Map<String, dynamic>>> listLocalFiles() async {
    final directory = await getLocalDownloadDirectory();
    if (!await directory.exists()) return [];
    final files = directory.listSync().whereType<File>()
        .where((f) => !f.path.endsWith('.part')).toList();
    final result = <Map<String, dynamic>>[];
    for (final file in files) {
      final stat = await file.stat();
      result.add({
        'path': file.path,
        'name': file.uri.pathSegments.isEmpty ? file.path : file.uri.pathSegments.last,
        'size': stat.size,
        'modified': stat.modified,
      });
    }
    result.sort((a, b) => (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));
    return result;
  }

  static Future<void> deleteLocalFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
