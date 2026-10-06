import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../widgets/glass_card.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});
  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  InAppWebViewController? _controller;
  final _url = TextEditingController(text: 'https://www.google.com');
  final List<String> _detected = [];
  double _progress = 0;

  void _open() {
    var value = _url.text.trim();
    if (value.isEmpty) return;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(value)));
  }

  void _detect(String url) {
    final v = url.toLowerCase();
    final possible = ['.mp4', '.m3u8', '.mpd', '.webm', '.mov', '.m4v', 'video'].any(v.contains);
    if (possible && !_detected.contains(url)) setState(() => _detected.insert(0, url));
  }

  Future<void> _download(String url) async {
    final item = await context.read<DownloadService>().addDownload(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(item == null ? 'لم أستطع استخراج فيديو من الرابط.' : 'بدأ تحميل: ${item.title}')),
    );
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المتصفح')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _url,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'اكتب رابط الموقع',
                    prefixIcon: Icon(Icons.language),
                  ),
                  onSubmitted: (_) => _open(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _open, icon: const Icon(Icons.arrow_forward)),
            ],
          ),
        ),
        if (_progress < 1) LinearProgressIndicator(value: _progress == 0 ? null : _progress),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri('https://www.google.com')),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useShouldInterceptRequest: true,
              useOnLoadResource: true,
            ),
            onWebViewCreated: (c) => _controller = c,
            onProgressChanged: (_, p) => setState(() => _progress = p / 100),
            onUpdateVisitedHistory: (_, url, __) {
              if (url != null) _url.text = url.toString();
            },
            onLoadResource: (_, resource) => _detect(resource.url.toString()),
            shouldInterceptRequest: (_, request) async {
              _detect(request.url.toString());
              return null;
            },
          ),
        ),
        if (_detected.isNotEmpty)
          SafeArea(
            top: false,
            child: GlassCard(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.download_for_offline),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${_detected.length} رابط فيديو تم اكتشافه')),
                  FilledButton(
                    onPressed: () => _download(_detected.first),
                    child: const Text('تحميل'),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
