import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuggestionsTab extends StatefulWidget {
  const SuggestionsTab({super.key});

  @override
  State<SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends State<SuggestionsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = Supabase.instance.client
        .from('suggestions')
        .select(
            'id,name,contact_info,subject,message,kind,status,admin_reply,replied_at,created_at')
        .order('created_at', ascending: false);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await Supabase.instance.client.from('suggestions').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث حالة الرسالة.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الحالة: $error')),
      );
    }
  }

  Future<void> _reply(Map<String, dynamic> item) async {
    final controller = TextEditingController(
      text: item['admin_reply']?.toString() ?? '',
    );
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل رد الإدارة'),
          content: TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            maxLength: 3000,
            decoration: const InputDecoration(
              labelText: 'الرد أو ملاحظة المتابعة',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حفظ كإجابة'),
            ),
          ],
        ),
      ),
    );
    if (shouldSave != true) {
      controller.dispose();
      return;
    }

    final reply = controller.text.trim();
    controller.dispose();
    if (reply.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اكتب الرد قبل الحفظ.')),
        );
      }
      return;
    }

    try {
      await Supabase.instance.client.from('suggestions').update({
        'admin_reply': reply,
        'status': 'answered',
        'replied_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', item['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ رد الإدارة في سجل الرسالة.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الرد: $error')),
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
          if (snapshot.hasError) return _buildError();
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) return _buildEmpty();
          return RefreshIndicator(
            color: const Color(0xFF193F38),
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) => _InquiryCard(
                item: items[index],
                onReview: () =>
                    _updateStatus(items[index]['id'].toString(), 'in_review'),
                onClose: () =>
                    _updateStatus(items[index]['id'].toString(), 'closed'),
                onReply: () => _reply(items[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_unread_chat_alt_outlined,
                size: 64, color: Color(0xFFCBD5E1)),
            SizedBox(height: 16),
            Text(
              'لا توجد اقتراحات أو أسئلة حالياً',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: FilledButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
      );
}

class _InquiryCard extends StatelessWidget {
  const _InquiryCard({
    required this.item,
    required this.onReview,
    required this.onClose,
    required this.onReply,
  });

  final Map<String, dynamic> item;
  final VoidCallback onReview;
  final VoidCallback onClose;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final kind = item['kind']?.toString() == 'question' ? 'سؤال' : 'اقتراح';
    final isQuestion = kind == 'سؤال';
    final status = item['status']?.toString() ?? 'new';
    final reply = item['admin_reply']?.toString().trim();
    final contact = item['contact_info']?.toString().trim();
    final subject = item['subject']?.toString().trim();

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
                  backgroundColor: (isQuestion ? Colors.indigo : Colors.amber)
                      .withOpacity(0.12),
                  child: Icon(
                    isQuestion
                        ? Icons.help_outline_rounded
                        : Icons.lightbulb_outline_rounded,
                    color: isQuestion ? Colors.indigo : Colors.amber.shade800,
                  ),
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
                      Text(
                        '$kind • ${_formatDate(item['created_at'])}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            if (subject?.isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Text(
                subject!,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFF193F38),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              item['message']?.toString() ?? '',
              style: const TextStyle(
                height: 1.5,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (contact?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.contact_mail_outlined,
                      size: 17, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SelectableText(
                      contact!,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (reply?.isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6F3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'رد الإدارة: $reply',
                  style: const TextStyle(
                    color: Color(0xFF193F38),
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status == 'new')
                  OutlinedButton.icon(
                    onPressed: onReview,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('قيد المراجعة'),
                  ),
                FilledButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply_rounded, size: 18),
                  label: Text(
                      reply?.isNotEmpty == true ? 'تعديل الرد' : 'تسجيل رد'),
                ),
                if (status != 'closed')
                  TextButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('إغلاق'),
                  ),
              ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final data = switch (status) {
      'in_review' => ('قيد المراجعة', const Color(0xFFD97706)),
      'answered' => ('تم الرد', const Color(0xFF2563EB)),
      'closed' => ('مغلق', const Color(0xFF64748B)),
      _ => ('جديد', const Color(0xFF059669)),
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
