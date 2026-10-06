import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ExtractedMedia {
  final String url;
  final String title;
  final String extension;
  final String mimeType;
  final int? size;

  const ExtractedMedia({
    required this.url,
    required this.title,
    required this.extension,
    required this.mimeType,
    this.size,
  });
}

class WebExtractorService {
  final YoutubeExplode _youtube = YoutubeExplode();

  bool isYoutube(String url) {
    final v = url.toLowerCase();
    return v.contains('youtube.com/') || v.contains('youtu.be/');
  }

  bool isVideoUrl(String url) {
    final v = url.toLowerCase();
    return ['.mp4', '.mkv', '.webm', '.mov', '.avi', '.m4v', '.ts', '.m3u8', '.mpd']
        .any(v.contains);
  }

  Future<ExtractedMedia?> extract(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) return null;

    if (isYoutube(clean)) return _extractYoutube(clean);

    if (isVideoUrl(clean)) {
      final extension = _extensionFromUrl(clean);
      return ExtractedMedia(
        url: clean,
        title: _titleFromUrl(clean),
        extension: extension,
        mimeType: _mimeFromExtension(extension),
      );
    }
    return null;
  }

  Future<ExtractedMedia?> _extractYoutube(String url) async {
    try {
      final video = await _youtube.videos.get(url);
      final manifest = await _youtube.videos.streams.getManifest(video.id);

      if (manifest.muxed.isNotEmpty) {
        final stream = manifest.muxed.withHighestVideoQuality();
        return ExtractedMedia(
          url: stream.url.toString(),
          title: video.title,
          extension: stream.container.name,
          mimeType: 'video/mp4',
          size: stream.size.totalBytes,
        );
      }
    } catch (_) {}
    return null;
  }

  String _titleFromUrl(String url) {
    try {
      final path = Uri.parse(url).path;
      if (path.contains('/')) {
        final last = path.split('/').last;
        if (last.isNotEmpty) {
          return Uri.decodeComponent(last).replaceAll(
            RegExp(r'\.(mp4|mkv|webm|mov|avi|m4v|ts)$'),
            '',
          );
        }
      }
    } catch (_) {}
    return 'فيديو جديد';
  }

  String _extensionFromUrl(String url) {
    try {
      final path = Uri.parse(url).path;
      if (path.contains('.')) {
        final value = path.split('.').last.toLowerCase();
        if (value.length <= 5) return value;
      }
    } catch (_) {}
    return 'mp4';
  }

  String _mimeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'webm': return 'video/webm';
      case 'mov': return 'video/quicktime';
      case 'mkv': return 'video/x-matroska';
      case 'm3u8': return 'application/vnd.apple.mpegurl';
      case 'mpd': return 'application/dash+xml';
      default: return 'video/mp4';
    }
  }

  void dispose() => _youtube.close();
}
