import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestimonialsTab extends StatefulWidget {
  const TestimonialsTab({super.key});

  @override
  State<TestimonialsTab> createState() => _TestimonialsTabState();
}

class _TestimonialsTabState extends State<TestimonialsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = Supabase.instance.client
        .from('testimonials')
        .select()
        .order('created_at', ascending: false);
  }

  Future<void> _updateStatus(String id, String status) async {
    await Supabase.instance.client
        .from('testimonials')
        .update({'status': status}).eq('id', id);
    setState(() => _load());
  }

  Future<void> _delete(String id) async {
    await Supabase.instance.client.from('testimonials').delete().eq('id', id);
    setState(() => _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'تعذر تحميل تجارب الزوار. يرجى التحقق من الاتصال والصلاحيات.'),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('لا توجد تجارب زوار مضافة بعد'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final status = item['status'] ?? 'pending';
            final photos =
                item['photos'] is List ? item['photos'] as List : const [];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(item['name'] ?? 'زائر',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(item['message'] ?? ''),
                    if (photos.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'مرفق ${photos.length} صورة',
                        style: const TextStyle(
                          color: Color(0xFF193F38),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text('الحالة: $status',
                        style: TextStyle(
                            color: status == 'approved'
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status != 'approved')
                      IconButton(
                        icon: const Icon(Icons.check_circle_rounded,
                            color: Colors.green),
                        tooltip: 'اعتماد ونشر',
                        onPressed: () =>
                            _updateStatus(item['id'].toString(), 'approved'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, color: Colors.red),
                      onPressed: () => _delete(item['id'].toString()),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
