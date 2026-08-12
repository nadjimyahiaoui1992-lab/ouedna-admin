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

  Future<void> _delete(String id) async {
    await Supabase.instance.client.from('memories').delete().eq('id', id);
    if (mounted) setState(() => _load());
  }

  void _openDialog([Map<String, dynamic>? memory]) async {
    final titleController = TextEditingController(text: memory?['title'] ?? '');
    final subtitleController =
        TextEditingController(text: memory?['subtitle'] ?? '');
    final imageController =
        TextEditingController(text: memory?['image_url'] ?? '');
    final descController =
        TextEditingController(text: memory?['description'] ?? '');

    await showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(memory == null ? 'إضافة ذاكرة تاريخية' : 'تعديل الذاكرة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'العنوان')),
                TextField(
                    controller: subtitleController,
                    decoration: const InputDecoration(labelText: 'العنوان الفرعي')),
                TextField(
                    controller: imageController,
                    decoration: const InputDecoration(labelText: 'رابط الصورة')),
                TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'الوصف'),
                    maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF193F38)),
              onPressed: () async {
                final data = {
                  'title': titleController.text.trim(),
                  'subtitle': subtitleController.text.trim(),
                  'image_url': imageController.text.trim(),
                  'description': descController.text.trim(),
                };
                if (memory == null) {
                  await Supabase.instance.client.from('memories').insert(data);
                } else {
                  await Supabase.instance.client
                      .from('memories')
                      .update(data)
                      .eq('id', memory['id']);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) setState(() => _load());
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('لا توجد ذكريات مضافة بعد'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: item['image_url'] != null &&
                          item['image_url'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(item['image_url'],
                              width: 60, height: 60, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.history_edu, size: 40),
                  title: Text(item['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(item['subtitle'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _openDialog(item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(item['id'].toString()),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF193F38),
        foregroundColor: Colors.white,
        onPressed: () => _openDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة ذاكرة'),
      ),
    );
  }
}
