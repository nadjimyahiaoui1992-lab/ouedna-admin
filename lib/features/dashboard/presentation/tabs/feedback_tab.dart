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
        .select(
            'id,name,message,rating,status,feedback_scope,place_id,created_at')
        .order('created_at', ascending: false);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await Supabase.instance.client
          .from('feedback')
          .update({'status': status}).eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              status == 'approved' ? 'تم اعتماد التقييم.' : 'تم رفض التقييم.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث التقييم: $error')),
      );
    }
  }

  Future<void> _delete(String id) async {
    try {
      await Supabase.instance.client.from('feedback').delete().eq('id', id);
      if (mounted) _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حذف التقييم: $error')),
      );
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
              child: CircularProgressIndicator(color: Color(0xFF193F38)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            );
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) return _buildEmptyState();
          return RefreshIndicator(
            onRefresh: _refresh,
            color: const Color(0xFF193F38),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) => _FeedbackCard(
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

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border_rounded, size: 64, color: Color(0xFFCBD5E1)),
          SizedBox(height: 16),
          Text(
            'لا توجد تقييمات أو ملاحظات حالياً',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
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
    final rating = (item['rating'] as num?)?.toInt() ?? 5;
    final status = item['status']?.toString() ?? 'pending';
    final isPending = status == 'pending';
    final isPlaceFeedback = item['feedback_scope']?.toString() == 'place';
    final placeId = item['place_id']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2EAE5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.amber.withOpacity(0.12),
                  child: const Icon(Icons.star_rounded, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name']?.toString().trim().isNotEmpty == true
                            ? item['name'].toString()
                            : 'زائر وادنا',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF193F38),
                        ),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: index < rating
                                ? Colors.amber
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _FeedbackStatus(status: status),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    isPlaceFeedback
                        ? Icons.place_outlined
                        : Icons.phone_android_rounded,
                    size: 15,
                  ),
                  label: Text(
                    isPlaceFeedback
                        ? 'رأي في معلم${placeId == null ? '' : ' #$placeId'}'
                        : 'تقييم التطبيق',
                  ),
                ),
                Text(
                  _formatDate(item['created_at']),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item['message']?.toString() ?? 'بدون ملاحظة',
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: Colors.red),
                      label: const Text('رفض',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('اعتماد'),
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: Color(0xFF64748B)),
                  label: const Text(
                    'حذف السجل',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic value) {
    try {
      final date = DateTime.parse(value.toString()).toLocal();
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'تاريخ غير محدد';
    }
  }
}

class _FeedbackStatus extends StatelessWidget {
  const _FeedbackStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final data = switch (status) {
      'approved' => ('معتمد', Colors.green),
      'rejected' => ('مرفوض', Colors.red),
      _ => ('جديد', const Color(0xFFD97706)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: data.$2.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        data.$1,
        style: TextStyle(
          color: data.$2,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
