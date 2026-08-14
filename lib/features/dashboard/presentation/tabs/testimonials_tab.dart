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

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await Supabase.instance.client
          .from('testimonials')
          .update({'status': status}).eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved'
                ? 'تم اعتماد التجربة بنجاح'
                : 'تم تحديث الحالة'),
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                status == 'approved' ? Colors.green : Colors.black87,
          ),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _delete(String id) async {
    try {
      await Supabase.instance.client.from('testimonials').delete().eq('id', id);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
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
          if (snapshot.hasError) {
            return _buildErrorState();
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
              itemBuilder: (context, index) => _TestimonialCard(
                item: items[index],
                onApprove: () =>
                    _updateStatus(items[index]['id'].toString(), 'approved'),
                onReject: () =>
                    _updateStatus(items[index]['id'].toString(), 'rejected'),
                onDelete: () => _delete(items[index]['id'].toString()),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          const Text('تعذر تحميل التجارب',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _refresh, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined, size: 64, color: Color(0xFFCBD5E1)),
          SizedBox(height: 16),
          Text('لا توجد تجارب زوار حالياً',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({
    required this.item,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = item['status'] ?? 'pending';
    final isPending = status == 'pending';
    final photos = item['photos'] is List ? item['photos'] as List : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EAE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF193F38).withOpacity(0.1),
                      child: const Icon(Icons.person_rounded,
                          color: Color(0xFF193F38)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? 'زائر',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF193F38)),
                          ),
                          Text(
                            item['created_at'] != null
                                ? 'نُشر في ${_formatDate(item['created_at'])}'
                                : 'تاريخ غير محدد',
                            style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(status),
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
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(photos[index].toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image_rounded)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                if (isPending) ...[
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: Colors.red),
                      label: const Text('رفض',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.green),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('اعتماد',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ] else
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: Color(0xFF64748B)),
                      label: const Text('حذف السجل',
                          style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = status == 'approved'
        ? Colors.green
        : (status == 'rejected' ? Colors.red : const Color(0xFFD97706));
    final label = status == 'approved'
        ? 'منشور'
        : (status == 'rejected' ? 'مرفوض' : 'معلق');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
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
