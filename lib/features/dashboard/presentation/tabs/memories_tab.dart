import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ouedna admin archive workflow: photos are selected locally, previewed, then
/// uploaded to the restricted `archive-images` bucket. No manual image URL is
/// accepted by this screen.
class MemoriesTab extends StatefulWidget {
  const MemoriesTab({super.key});

  @override
  State<MemoriesTab> createState() => _MemoriesTabState();
}

class _MemoriesTabState extends State<MemoriesTab> {
  late Future<List<_ArchiveRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_ArchiveRecord>> _load() async {
    final client = Supabase.instance.client;
    final responses = await Future.wait([
      client
          .from('old_memories')
          .select('id,image_url,caption,year,gallery,created_at')
          .order('created_at', ascending: false)
          .limit(100),
      client
          .from('heritage')
          .select('id,title,image,text,year,gallery,created_at')
          .order('created_at', ascending: false)
          .limit(100),
    ]);

    final records = <_ArchiveRecord>[
      ...(responses[0] as List)
          .whereType<Map<String, dynamic>>()
          .map(_ArchiveRecord.oldMemory),
      ...(responses[1] as List)
          .whereType<Map<String, dynamic>>()
          .map(_ArchiveRecord.heritage),
    ];
    records.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return records;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _openEditor([_ArchiveRecord? record]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ArchiveEditorDialog(record: record),
    );
    if (saved == true && mounted) await _refresh();
  }

  Future<void> _delete(_ArchiveRecord record) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('حذف مادة من الأرشيف؟'),
              content: Text(
                'سيُحذف «${record.title}» من أرشيف وادنا. لا يمكن استرجاع المادة من لوحة الإدارة بعد الحذف.',
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('إلغاء')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('حذف'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!shouldDelete) return;

    try {
      final client = Supabase.instance.client;
      await client.from(record.table).delete().eq('id', record.id);

      final storagePaths = record.imageUrls
          .map(_ArchiveStorage.pathFromPublicUrl)
          .whereType<String>()
          .toList(growable: false);
      if (storagePaths.isNotEmpty) {
        try {
          await client.storage
              .from(_ArchiveStorage.bucket)
              .remove(storagePaths);
        } catch (_) {
          // The database record is already deleted; a later cleanup can safely
          // remove an orphan file if network delivery of this request failed.
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المادة من الأرشيف.')),
        );
      }
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحذف: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      body: FutureBuilder<List<_ArchiveRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF193F38)));
          }
          if (snapshot.hasError) {
            return _ArchiveEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'تعذر تحميل الأرشيف',
              actionLabel: 'إعادة المحاولة',
              onAction: _refresh,
            );
          }

          final records = snapshot.data ?? const <_ArchiveRecord>[];
          if (records.isEmpty) {
            return _ArchiveEmptyState(
              icon: Icons.photo_library_outlined,
              title: 'الأرشيف جاهز لاستقبال الصور',
              subtitle:
                  'أضف أول صورة تاريخية أو مادة تراثية مباشرة من معرض هاتفك.',
              actionLabel: 'إضافة مادة أرشيفية',
              onAction: _openEditor,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: const Color(0xFF193F38),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: records.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return const _ArchiveGuidanceCard();
                final record = records[index - 1];
                return _ArchiveCard(
                  record: record,
                  onEdit: () => _openEditor(record),
                  onDelete: () => _delete(record),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        backgroundColor: const Color(0xFF193F38),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: const Text('إضافة للأرشيف',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _ArchiveEditorDialog extends StatefulWidget {
  const _ArchiveEditorDialog({this.record});

  final _ArchiveRecord? record;

  @override
  State<_ArchiveEditorDialog> createState() => _ArchiveEditorDialogState();
}

class _ArchiveEditorDialogState extends State<_ArchiveEditorDialog> {
  static const _maxImages = 8;

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _newImages = <XFile>[];

  late final TextEditingController _titleController;
  late final TextEditingController _yearController;
  late final TextEditingController _descriptionController;
  late _ArchiveKind _kind;
  late List<String> _savedImageUrls;
  var _isSaving = false;

  int get _imageCount => _savedImageUrls.length + _newImages.length;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _kind = record?.kind ?? _ArchiveKind.oldMemory;
    _savedImageUrls = List<String>.from(record?.imageUrls ?? const []);
    _titleController = TextEditingController(text: record?.title ?? '');
    _yearController = TextEditingController(text: record?.year ?? '');
    _descriptionController =
        TextEditingController(text: record?.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _imageCount;
    if (remaining <= 0) {
      _showMessage('الحد الأقصى لكل مادة هو $_maxImages صور.');
      return;
    }

    final picked =
        await _picker.pickMultiImage(imageQuality: 88, maxWidth: 2400);
    if (picked.isEmpty || !mounted) return;
    final accepted = picked.take(remaining).toList(growable: false);
    if (picked.length > remaining) {
      _showMessage(
          'تم اختيار أول $remaining صور فقط للحفاظ على حد $_maxImages صور.');
    }
    setState(() => _newImages.addAll(accepted));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageCount == 0) {
      _showMessage('اختر صورة واحدة على الأقل قبل الحفظ.');
      return;
    }

    setState(() => _isSaving = true);
    _UploadedArchiveImages? uploaded;
    try {
      uploaded = await _ArchiveStorage.upload(_newImages, _kind.folder);
      final urls = <String>[..._savedImageUrls, ...uploaded.urls];
      final client = Supabase.instance.client;
      final payload = _kind == _ArchiveKind.oldMemory
          ? <String, dynamic>{
              'image_url': urls.first,
              'caption': _titleController.text.trim(),
              'year': _nullableText(_yearController.text),
              'gallery': urls.skip(1).toList(growable: false),
            }
          : <String, dynamic>{
              'title': _titleController.text.trim(),
              'image': urls.first,
              'text': _nullableText(_descriptionController.text),
              'year': _nullableText(_yearController.text),
              'gallery': urls.skip(1).toList(growable: false),
            };

      final existing = widget.record;
      if (existing == null) {
        await client.from(_kind.table).insert(payload);
      } else {
        await client.from(existing.table).update(payload).eq('id', existing.id);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (uploaded != null && uploaded.paths.isNotEmpty) {
        try {
          await Supabase.instance.client.storage
              .from(_ArchiveStorage.bucket)
              .remove(uploaded.paths);
        } catch (_) {
          // Retaining an unreachable file is preferable to hiding the original
          // error; the authenticated admin can remove it later if necessary.
        }
      }
      if (mounted) {
        _showMessage('تعذر حفظ المادة أو رفع الصور: $error');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _nullableText(String input) {
    final value = input.trim();
    return value.isEmpty ? null : value;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.record != null;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          editing ? 'تعديل مادة أرشيفية' : 'مادة جديدة في ذاكرة الوادي',
          style: const TextStyle(
              fontWeight: FontWeight.w900, color: Color(0xFF193F38)),
        ),
        content: SizedBox(
          width: 520,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<_ArchiveKind>(
                    value: _kind,
                    decoration:
                        _decoration('نوع المادة', Icons.category_outlined),
                    items: _ArchiveKind.values
                        .map((kind) => DropdownMenuItem(
                            value: kind, child: Text(kind.label)))
                        .toList(growable: false),
                    onChanged: editing
                        ? null
                        : (value) {
                            if (value != null) setState(() => _kind = value);
                          },
                  ),
                  const SizedBox(height: 12),
                  _EditorField(
                    controller: _titleController,
                    label: _kind == _ArchiveKind.oldMemory
                        ? 'عنوان الصورة أو تعليقها'
                        : 'عنوان المادة التراثية',
                    icon: Icons.title_rounded,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'اكتب عنواناً واضحاً للمادة.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _EditorField(
                    controller: _yearController,
                    label: 'السنة أو الفترة التاريخية',
                    hint: 'مثال: خمسينيات القرن الماضي',
                    icon: Icons.event_outlined,
                  ),
                  if (_kind == _ArchiveKind.heritage) ...[
                    const SizedBox(height: 12),
                    _EditorField(
                      controller: _descriptionController,
                      label: 'وصف أو سياق تاريخي',
                      icon: Icons.notes_rounded,
                      maxLines: 4,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ImageUploadArea(
                    imageCount: _imageCount,
                    limit: _maxImages,
                    onTap: _isSaving ? null : _pickImages,
                  ),
                  if (_savedImageUrls.isNotEmpty || _newImages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ArchiveImageStrip(
                      savedUrls: _savedImageUrls,
                      newImages: _newImages,
                      enabled: !_isSaving,
                      onRemoveSaved: (index) =>
                          setState(() => _savedImageUrls.removeAt(index)),
                      onRemoveNew: (index) =>
                          setState(() => _newImages.removeAt(index)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'لا تُدخل روابط صور يدوياً. تُرفع الصور المختارة مباشرة إلى تخزين وادنا وتُعرض للزوار بعد الحفظ.',
                    style: TextStyle(
                        color: Color(0xFF64748B), fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF193F38),
              foregroundColor: Colors.white,
            ),
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_isSaving ? 'جارٍ رفع الصور…' : 'رفع وحفظ'),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}

class _ArchiveGuidanceCard extends StatelessWidget {
  const _ArchiveGuidanceCard();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3EF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFC9DED6)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.photo_library_rounded, color: Color(0xFF193F38)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'يمكنك اختيار عدة صور من الهاتف، معاينتها، ثم رفعها مباشرة إلى أرشيف وادنا. لا تستخدم هذه الصفحة روابط الصور.',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF193F38),
                    height: 1.45),
              ),
            ),
          ]),
        ),
      );
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard(
      {required this.record, required this.onEdit, required this.onDelete});

  final _ArchiveRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2EAE5)),
        ),
        child: Column(children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 60,
                height: 60,
                child: record.imageUrls.isNotEmpty
                    ? Image.network(record.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFFEAF3EF),
                            child: Icon(Icons.broken_image_outlined)))
                    : const ColoredBox(
                        color: Color(0xFFEAF3EF),
                        child: Icon(Icons.photo_outlined)),
              ),
            ),
            title: Text(record.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: Color(0xFF193F38))),
            subtitle: Text(
              '${record.kind.label}${record.year == null ? '' : ' · ${record.year}'} · ${record.imageUrls.length} صور',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('تعديل المادة')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف المادة',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
          if (record.description?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(record.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        height: 1.45, color: Color(0xFF475569))),
              ),
            ),
        ]),
      );
}

class _ArchiveEmptyState extends StatelessWidget {
  const _ArchiveEmptyState(
      {required this.icon,
      required this.title,
      required this.actionLabel,
      required this.onAction,
      this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 62, color: const Color(0xFFB7CBC1)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Color(0xFF193F38))),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B))),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: Text(actionLabel)),
          ]),
        ),
      );
}

class _EditorField extends StatelessWidget {
  const _EditorField(
      {required this.controller,
      required this.label,
      required this.icon,
      this.hint,
      this.maxLines = 1,
      this.validator});

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      );
}

class _ImageUploadArea extends StatelessWidget {
  const _ImageUploadArea(
      {required this.imageCount, required this.limit, required this.onTap});

  final int imageCount;
  final int limit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'اختيار صور الأرشيف من الهاتف',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8F5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8AB5A3), width: 1.2),
            ),
            child: Row(children: [
              const Icon(Icons.add_photo_alternate_rounded,
                  color: Color(0xFF193F38), size: 30),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('اختيار صور من الهاتف',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF193F38))),
                      SizedBox(height: 3),
                      Text(
                        'JPG أو PNG أو WebP، بحد أقصى 8 ميغابايت للصورة.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ]),
              ),
              Text('$imageCount/$limit',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, color: Color(0xFF193F38))),
            ]),
          ),
        ),
      );
}

class _ArchiveImageStrip extends StatelessWidget {
  const _ArchiveImageStrip(
      {required this.savedUrls,
      required this.newImages,
      required this.enabled,
      required this.onRemoveSaved,
      required this.onRemoveNew});

  final List<String> savedUrls;
  final List<XFile> newImages;
  final bool enabled;
  final ValueChanged<int> onRemoveSaved;
  final ValueChanged<int> onRemoveNew;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 90,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: savedUrls.length + newImages.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index < savedUrls.length) {
              return _ImageThumb.network(
                savedUrls[index],
                enabled: enabled,
                onRemove: () => onRemoveSaved(index),
              );
            }
            final localIndex = index - savedUrls.length;
            return _ImageThumb.local(
              newImages[localIndex],
              enabled: enabled,
              onRemove: () => onRemoveNew(localIndex),
            );
          },
        ),
      );
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb.network(this.url,
      {required this.enabled, required this.onRemove})
      : image = null;

  const _ImageThumb.local(this.image,
      {required this.enabled, required this.onRemove})
      : url = null;

  final String? url;
  final XFile? image;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) =>
      Stack(clipBehavior: Clip.none, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 90,
            height: 90,
            child: url != null
                ? Image.network(url!, fit: BoxFit.cover)
                : FutureBuilder<Uint8List>(
                    future: image!.readAsBytes(),
                    builder: (_, snapshot) => snapshot.hasData
                        ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                        : const ColoredBox(
                            color: Color(0xFFEAF3EF),
                            child: Center(child: CircularProgressIndicator())),
                  ),
          ),
        ),
        PositionedDirectional(
          top: -6,
          end: -6,
          child: IconButton.filled(
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: Colors.red),
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.close_rounded, size: 16),
          ),
        ),
      ]);
}

enum _ArchiveKind {
  oldMemory('old_memories', 'صور قديمة', 'old_memories'),
  heritage('heritage', 'مادة تراثية', 'heritage');

  const _ArchiveKind(this.table, this.label, this.folder);
  final String table;
  final String label;
  final String folder;
}

class _ArchiveRecord {
  const _ArchiveRecord(
      {required this.id,
      required this.table,
      required this.kind,
      required this.title,
      required this.imageUrls,
      required this.createdAt,
      this.description,
      this.year});

  factory _ArchiveRecord.oldMemory(Map<String, dynamic> row) => _ArchiveRecord(
        id: row['id'],
        table: _ArchiveKind.oldMemory.table,
        kind: _ArchiveKind.oldMemory,
        title: _text(row['caption'], fallback: 'صورة من ذاكرة الوادي'),
        description: null,
        year: _nullableText(row['year']),
        imageUrls: _imageUrls(row['image_url'], row['gallery']),
        createdAt: _date(row['created_at']),
      );

  factory _ArchiveRecord.heritage(Map<String, dynamic> row) => _ArchiveRecord(
        id: row['id'],
        table: _ArchiveKind.heritage.table,
        kind: _ArchiveKind.heritage,
        title: _text(row['title'], fallback: 'مادة تراثية'),
        description: _nullableText(row['text']),
        year: _nullableText(row['year']),
        imageUrls: _imageUrls(row['image'], row['gallery']),
        createdAt: _date(row['created_at']),
      );

  final dynamic id;
  final String table;
  final _ArchiveKind kind;
  final String title;
  final String? description;
  final String? year;
  final List<String> imageUrls;
  final DateTime createdAt;

  static String _text(dynamic value, {required String fallback}) {
    final normalized = _nullableText(value);
    return normalized ?? fallback;
  }

  static String? _nullableText(dynamic value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static DateTime _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  static List<String> _imageUrls(dynamic primary, dynamic gallery) {
    final urls = <String>[];
    void add(dynamic value) {
      final url = value?.toString().trim() ?? '';
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }

    add(primary);
    if (gallery is List) {
      for (final value in gallery) {
        add(value);
      }
    }
    return urls;
  }
}

class _ArchiveStorage {
  static const bucket = 'archive-images';
  static const _maxBytes = 8 * 1024 * 1024;

  static Future<_UploadedArchiveImages> upload(
      List<XFile> files, String folder) async {
    if (files.isEmpty) return const _UploadedArchiveImages([], []);
    final storage = Supabase.instance.client.storage.from(bucket);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final urls = <String>[];
    final paths = <String>[];

    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > _maxBytes) {
        throw const FormatException('يجب ألا يتجاوز حجم كل صورة 8 ميغابايت.');
      }
      final extension = _extension(file.name);
      final path = '$folder/$stamp-$index.$extension';
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions:
            FileOptions(contentType: _contentType(extension), upsert: false),
      );
      paths.add(path);
      urls.add(storage.getPublicUrl(path));
    }
    return _UploadedArchiveImages(urls, paths);
  }

  static String? pathFromPublicUrl(String url) {
    const marker = '/storage/v1/object/public/$bucket/';
    final index = url.indexOf(marker);
    if (index == -1) return null;
    return Uri.decodeComponent(url.substring(index + marker.length));
  }

  static String _extension(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  static String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

class _UploadedArchiveImages {
  const _UploadedArchiveImages(this.urls, this.paths);
  final List<String> urls;
  final List<String> paths;
}
