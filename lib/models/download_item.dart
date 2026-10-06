enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  cancelled,
  failed,
}

class DownloadItem {
  final String id;
  String title;
  String url;
  String filePath;
  String? safUri;
  int totalBytes;
  int downloadedBytes;
  double progress;
  double speed;
  DateTime createdAt;
  DateTime? completedAt;
  DownloadStatus status;
  String? error;

  DownloadItem({
    required this.id,
    required this.title,
    required this.url,
    required this.filePath,
    this.safUri,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.progress = 0,
    this.speed = 0,
    DateTime? createdAt,
    this.completedAt,
    this.status = DownloadStatus.queued,
    this.error,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'url': url,
    'filePath': filePath,
    'safUri': safUri,
    'totalBytes': totalBytes,
    'downloadedBytes': downloadedBytes,
    'progress': progress,
    'speed': speed,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'status': status.name,
    'error': error,
  };

  factory DownloadItem.fromMap(Map map) => DownloadItem(
    id: map['id']?.toString() ?? '',
    title: map['title']?.toString() ?? 'تحميل',
    url: map['url']?.toString() ?? '',
    filePath: map['filePath']?.toString() ?? '',
    safUri: map['safUri']?.toString(),
    totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
    downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
    progress: (map['progress'] as num?)?.toDouble() ?? 0,
    speed: (map['speed'] as num?)?.toDouble() ?? 0,
    createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    completedAt: map['completedAt'] == null
        ? null
        : DateTime.tryParse(map['completedAt'].toString()),
    status: DownloadStatus.values.firstWhere(
      (value) => value.name == map['status'],
      orElse: () => DownloadStatus.queued,
    ),
    error: map['error']?.toString(),
  );
}
