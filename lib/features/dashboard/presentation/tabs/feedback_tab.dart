import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackTab extends StatefulWidget {
  const FeedbackTab({super.key});

  @override
  State<FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<FeedbackTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = Supabase.instance.client
        .from('feedback')
        .select()
        .order('created_at', ascending: false);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _delete(String id) async {
    try {
      await Supabase.instance.client.from('feedback').delete().eq('id', id);
      _refresh();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
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
              itemBuilder: (context, index) => _FeedbackCard(
                item: items[index],
                onDelete: () => _delete(items[index]['id'].toString()),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.forum_outlined, size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text('لا توجد آراء مسجلة حالياً',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.item, required this.onDelete});
  final Map<String, dynamic> item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rating = (item['rating'] as num?)?.toDouble() ?? 5.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EAE5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.amber.withOpacity(0.1),
                  child: const Icon(Icons.star_rounded, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'] ?? 'زائر',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF193F38))),
                      Row(
                        children: List.generate(
                            5,
                            (i) => Icon(Icons.star_rounded,
                                size: 14,
                                color: i < rating
                                    ? Colors.amber
                                    : Colors.grey.shade300)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red, size: 20)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item['message'] ?? 'بدون رسالة',
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item['created_at'] != null
                    ? _formatDate(item['created_at'])
                    : '',
                style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final date = DateTime.parse(iso);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return iso;
    }
  }
}
