import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoriesTab extends StatefulWidget {
  const MemoriesTab({super.key});

  @override
  State<MemoriesTab> createState() => _MemoriesTabState();
}

class _MemoriesTabState extends State<MemoriesTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = Supabase.instance.client
        .from('memories')
        .select()
        .order('created_at', ascending: false);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _delete(String id) async {
    try {
      await Supabase.instance.client.from('memories').delete().eq('id', id);
      _refresh();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  void _openDialog([Map<String, dynamic>? memory]) async {
    final titleC = TextEditingController(text: memory?['title'] ?? '');
    final subC = TextEditingController(text: memory?['subtitle'] ?? '');
    final imgC = TextEditingController(text: memory?['image_url'] ?? '');
    final descC = TextEditingController(text: memory?['description'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(memory == null ? 'إضافة ذاكرة تراثية' : 'تعديل الذاكرة',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, color: Color(0xFF193F38))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField('العنوان الرئيسي', titleC, Icons.title_rounded),
                const SizedBox(height: 12),
                _buildField('العنوان الفرعي', subC, Icons.subtitles_rounded),
                const SizedBox(height: 12),
                _buildField('رابط الصورة', imgC, Icons.image_rounded),
                const SizedBox(height: 12),
                _buildField('الوصف التاريخي', descC, Icons.description_rounded,
                    maxLines: 4),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(fontWeight: FontWeight.w900))),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF193F38),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                final data = {
                  'title': titleC.text.trim(),
                  'subtitle': subC.text.trim(),
                  'image_url': imgC.text.trim(),
                  'description': descC.text.trim(),
                };
                if (memory == null) {
                  await Supabase.instance.client.from('memories').insert(data);
                } else {
                  await Supabase.instance.client
                      .from('memories')
                      .update(data)
                      .eq('id', memory['id']);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _refresh();
              },
              child: const Text('حفظ الذاكرة',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
      String label, TextEditingController controller, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF193F38)));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return _buildEmptyState();
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            color: const Color(0xFF193F38),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) => _MemoryCard(
                item: items[index],
                onEdit: () => _openDialog(items[index]),
                onDelete: () => _delete(items[index]['id'].toString()),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDialog(),
        backgroundColor: const Color(0xFF193F38),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.history_edu_rounded),
        label: const Text('إضافة تراث',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_stories_rounded,
              size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text('لا توجد سجلات تراثية حالياً',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard(
      {required this.item, required this.onEdit, required this.onDelete});
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EAE5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: item['image_url'] != null &&
                  item['image_url'].toString().isNotEmpty
              ? Image.network(item['image_url'],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_rounded))
              : const Icon(Icons.history_edu_rounded, color: Color(0xFFCBD5E1)),
        ),
        title: Text(item['title'] ?? 'بدون عنوان',
            style: const TextStyle(
                fontWeight: FontWeight.w900, color: Color(0xFF193F38))),
        subtitle: Text(item['subtitle'] ?? '',
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded,
                    color: Color(0xFF193F38), size: 20)),
            IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 20)),
          ],
        ),
      ),
    );
  }
}
