import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/media/image_upload_mime.dart';

class MediaManagerTab extends StatefulWidget {
  const MediaManagerTab({super.key});

  @override
  State<MediaManagerTab> createState() => _MediaManagerTabState();
}

class _MediaManagerTabState extends State<MediaManagerTab> {
  final _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _galleryFuture;
  String _query = '';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    _galleryFuture = _client
        .from('gallery')
        .select(
            'id,place_id,image_url,title,description,is_cover,sort_order,created_at')
        .order('created_at', ascending: false);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _galleryFuture;
  }

  Future<void> _openUpload() async {
    final places = await _client
        .from('places')
        .select('id,name')
        .order('name', ascending: true);
    if (!mounted) return;
    final request = await showDialog<_MediaUploadRequest>(
      context: context,
      builder: (_) => _MediaUploadDialog(places: places),
    );
    if (request == null || !mounted) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final rows = <Map<String, dynamic>>[];
      for (var index = 0; index < request.files.length; index++) {
        final file = request.files[index];
        final bytes = await file.readAsBytes();
        final extension = ImageUploadMime.normalizedExtension(file.name);
        final contentType = ImageUploadMime.contentTypeForExtension(extension);
        final path =
            'places/${request.placeId}/gallery_${now}_$index.$extension';
        await _client.storage.from('images').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );
        rows.add({
          'place_id': request.placeId,
          'image_url': _client.storage.from('images').getPublicUrl(path),
          'title': file.name,
          'is_cover': index == 0,
          'sort_order': index,
        });
      }
      if (rows.isNotEmpty) await _client.from('gallery').insert(rows);
      if (!mounted) return;
      _showMessage('تم رفع ${rows.length} صورة وربطها بالمعلم.');
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMessage('تعذر رفع الصور: $error', error: true);
    }
  }

  Future<void> _deleteImage(Map<String, dynamic> image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الصورة'),
          content: const Text('سيتم حذف سجل الصورة وملفها من التخزين إن أمكن.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await _client.from('gallery').delete().eq('id', image['id']);
      final path = _storagePath(image['image_url']?.toString());
      if (path != null) await _client.storage.from('images').remove([path]);
      if (!mounted) return;
      _showMessage('تم حذف الصورة.');
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMessage('تعذر حذف الصورة: $error', error: true);
    }
  }

  String? _storagePath(String? url) {
    if (url == null || url.isEmpty) return null;
    const marker = '/storage/v1/object/public/images/';
    final index = url.indexOf(marker);
    if (index < 0) return null;
    return Uri.decodeComponent(url.substring(index + marker.length));
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Colors.red.shade700 : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EC),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _galleryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تعذر تحميل الوسائط، إعادة المحاولة'),
              ),
            );
          }
          final images =
              (snapshot.data ?? const <Map<String, dynamic>>[]).where((image) {
            if (_query.isEmpty) return true;
            final text = [
              image['title'],
              image['description'],
              image['place_id']
            ].whereType<Object>().join(' ').toLowerCase();
            return text.contains(_query);
          }).toList(growable: false);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildToolbar(images.length)),
                if (images.isEmpty)
                  SliverFillRemaining(
                      hasScrollBody: false, child: _emptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _MediaCard(
                          image: images[index],
                          onDelete: () => _deleteImage(images[index]),
                        ),
                        childCount: images.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisExtent: 246,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$count صورة في المعرض',
                  style: const TextStyle(
                      color: Color(0xFF173F36),
                      fontWeight: FontWeight.w900,
                      fontSize: 18),
                ),
              ),
              FilledButton.icon(
                onPressed: _openUpload,
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('رفع صور'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'ابحث في أسماء الصور أو المعالم...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE7E5DF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE7E5DF)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 56, color: Color(0xFFB6C1BA)),
            SizedBox(height: 12),
            Text('لا توجد صور مطابقة',
                style: TextStyle(
                    color: Color(0xFF58665F), fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.image, required this.onDelete});

  final Map<String, dynamic> image;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final url = image['image_url']?.toString() ?? '';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                url.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFEFF3F0),
                        child: Icon(Icons.image_not_supported_outlined),
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFFEFF3F0),
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                if (image['is_cover'] == true)
                  const PositionedDirectional(
                    top: 8,
                    start: 8,
                    child: Chip(
                      label: Text('رئيسية'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: IconButton(
                    onPressed: onDelete,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(.9),
                      foregroundColor: Colors.red,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
            child: Text(
              image['title']?.toString() ?? 'صورة بدون عنوان',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF173F36),
                  fontSize: 12,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaUploadRequest {
  const _MediaUploadRequest({required this.placeId, required this.files});

  final int placeId;
  final List<XFile> files;
}

class _MediaUploadDialog extends StatefulWidget {
  const _MediaUploadDialog({required this.places});

  final List<dynamic> places;

  @override
  State<_MediaUploadDialog> createState() => _MediaUploadDialogState();
}

class _MediaUploadDialogState extends State<_MediaUploadDialog> {
  final _picker = ImagePicker();
  final List<XFile> _files = [];
  int? _placeId;

  Future<void> _pick() async {
    final files = await _picker.pickMultiImage();
    if (files.isNotEmpty) setState(() => _files.addAll(files));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('رفع صور إلى المعرض'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                value: _placeId,
                decoration: const InputDecoration(
                  labelText: 'المعلم المرتبط',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                items: widget.places
                    .map((place) => DropdownMenuItem<int>(
                          value: (place['id'] as num).toInt(),
                          child: Text(place['name']?.toString() ?? 'بدون اسم'),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _placeId = value),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_files.isEmpty
                    ? 'اختيار الصور'
                    : '${_files.length} صورة مختارة'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: _placeId == null || _files.isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      _MediaUploadRequest(placeId: _placeId!, files: _files),
                    ),
            child: const Text('رفع وربط'),
          ),
        ],
      ),
    );
  }
}
