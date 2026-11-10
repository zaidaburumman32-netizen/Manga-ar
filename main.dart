import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _headers = {'User-Agent': 'ArabicMangaReader/1.0'};

Future<Map<String, dynamic>> api(String path, [Map<String, dynamic>? q]) async {
  final r = await http.get(Uri.https('api.mangadex.org', path, q), headers: _headers);
  if (r.statusCode != 200) throw Exception('خطأ في الاتصال (${r.statusCode})');
  return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
}

class Manga {
  final String id, title, desc;
  final String? cover;
  Manga(this.id, this.title, this.desc, this.cover);

  factory Manga.fromJson(Map<String, dynamic> j) {
    final a = j['attributes'] as Map<String, dynamic>;
    String pick(Map? m) {
      if (m == null || m.isEmpty) return '';
      return (m['ar'] ?? m['en'] ?? m.values.first).toString();
    }

    String? cover;
    for (final r in (j['relationships'] as List)) {
      if (r['type'] == 'cover_art' && r['attributes'] != null) {
        cover =
            'https://uploads.mangadex.org/covers/${j['id']}/${r['attributes']['fileName']}.256.jpg';
      }
    }
    return Manga(j['id'], pick(a['title'] as Map?), pick(a['description'] as Map?), cover);
  }
}

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مانهوا عربي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ctrl = TextEditingController();
  List<Manga> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String q = '']) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{
        'limit': '30',
        'availableTranslatedLanguage[]': ['ar'],
        'includes[]': ['cover_art'],
        'contentRating[]': ['safe', 'suggestive'],
        'hasAvailableChapters': 'true',
        if (q.isNotEmpty) 'title': q else 'order[followedCount]': 'desc',
      };
      final res = await api('/manga', params);
      _items = (res['data'] as List).map((e) => Manga.fromJson(e)).toList();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.search,
          onSubmitted: _load,
          decoration: const InputDecoration(
            hintText: 'ابحث عن مانهوا أو مانجا...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => _load(_ctrl.text.trim())),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? const Center(child: Text('لا توجد نتائج'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final m = _items[i];
                        return InkWell(
                          onTap: () => Navigator.push(
                              context, MaterialPageRoute(builder: (_) => DetailPage(m))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: m.cover == null
                                      ? const Center(child: Icon(Icons.book, size: 48))
                                      : Image.network(m.cover!,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          headers: _headers,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(child: Icon(Icons.broken_image))),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class DetailPage extends StatefulWidget {
  final Manga manga;
  const DetailPage(this.manga, {super.key});
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  List<Map<String, dynamic>> _chapters = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await api('/manga/${widget.manga.id}/feed', {
        'translatedLanguage[]': ['ar'],
        'order[chapter]': 'asc',
        'limit': '500',
        'includeExternalUrl': '0',
        'contentRating[]': ['safe', 'suggestive'],
      });
      _chapters = (res['data'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.manga;
    return Scaffold(
      appBar: AppBar(title: Text(m.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  children: [
                    if (m.desc.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(m.desc, maxLines: 6, overflow: TextOverflow.ellipsis),
                      ),
                    if (_chapters.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text('لا توجد فصول عربية متاحة')),
                      ),
                    for (final c in _chapters)
                      ListTile(
                        title: Text(
                            'الفصل ${c['attributes']['chapter'] ?? '-'}'
                            '${(c['attributes']['title'] ?? '').toString().isNotEmpty ? ' - ${c['attributes']['title']}' : ''}'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ReaderPage(
                                  c['id'], 'الفصل ${c['attributes']['chapter'] ?? '-'}')),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class ReaderPage extends StatefulWidget {
  final String chapterId, label;
  const ReaderPage(this.chapterId, this.label, {super.key});
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  List<String> _pages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await api('/at-home/server/${widget.chapterId}');
      final base = res['baseUrl'];
      final hash = res['chapter']['hash'];
      final files = (res['chapter']['data'] as List).cast<String>();
      _pages = files.map((f) => '$base/data/$hash/$f').toList();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.label)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _pages.isEmpty
                  ? const Center(child: Text('هذا الفصل لا يحتوي صفحات'))
                  : InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: ListView.builder(
                        itemCount: _pages.length,
                        itemBuilder: (_, i) => Image.network(
                          _pages[i],
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          headers: _headers,
                          loadingBuilder: (_, child, p) => p == null
                              ? child
                              : const SizedBox(
                                  height: 300,
                                  child: Center(child: CircularProgressIndicator())),
                          errorBuilder: (_, __, ___) => const SizedBox(
                              height: 200, child: Center(child: Text('تعذّر تحميل الصفحة'))),
                        ),
                      ),
                    ),
    );
  }
}
