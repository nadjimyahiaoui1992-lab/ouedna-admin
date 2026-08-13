import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementComposerDialog extends StatefulWidget {
  const AnnouncementComposerDialog({super.key});

  @override
  State<AnnouncementComposerDialog> createState() =>
      _AnnouncementComposerDialogState();
}

class _AnnouncementComposerDialogState
    extends State<AnnouncementComposerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _url = TextEditingController();
  String _type = 'announcement';
  String _targetType = 'none';
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate() || _sending) return;
    setState(() => _sending = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'publish-visitor-notification',
        body: {
          'type': _type,
          'title': _title.text.trim(),
          'body': _body.text.trim(),
          'target_type': _targetType,
          'target_url': _targetType == 'url' ? _url.text.trim() : null,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        final data = response.data;
        final reason = data is Map ? data['error']?.toString() : null;
        throw StateError(reason ?? 'تعذر نشر الإشعار.');
      }
      if (!mounted) return;
      final data = response.data;
      final pushStatus = data is Map ? data['push_status']?.toString() : null;
      Navigator.of(context).pop(
        pushStatus == 'sent'
            ? 'تم نشر الإشعار وإرساله إلى الأجهزة المسجلة.'
            : 'تم نشر الإشعار داخل وادنا. فعّل Firebase لإرساله فورياً إلى الأجهزة المغلقة.',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر النشر: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
      title: Row(
        children: [
          const Icon(Icons.campaign_rounded, color: Color(0xFF7C3AED)),
          const SizedBox(width: 10),
          const Expanded(child: Text('نشر إشعار للزوار')),
          IconButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'سيظهر الإشعار في جرس وادنا لجميع الزوار. المعالم المنشورة حديثاً تُضاف تلقائياً.',
                  style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'نوع الإشعار',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'announcement', child: Text('إعلان مهم')),
                    DropdownMenuItem(
                        value: 'event', child: Text('فعالية أو حدث')),
                    DropdownMenuItem(
                        value: 'safety', child: Text('تنبيه سلامة')),
                  ],
                  onChanged: _sending
                      ? null
                      : (value) => setState(() => _type = value!),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    hintText: 'مثال: فعالية ثقافية جديدة في الوادي',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'أدخل عنواناً للإشعار.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _body,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'التفاصيل',
                    hintText: 'اكتب معلومة مختصرة ومفيدة للزائر.',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.subject_rounded),
                  ),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'أدخل تفاصيل الإشعار.'
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _targetType,
                  decoration: const InputDecoration(
                    labelText: 'عند الضغط على الإشعار',
                    prefixIcon: Icon(Icons.ads_click_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'none', child: Text('عرض الإشعار فقط')),
                    DropdownMenuItem(
                        value: 'update', child: Text('فتح مركز تحديث وادنا')),
                    DropdownMenuItem(
                        value: 'url', child: Text('فتح رابط خارجي آمن')),
                  ],
                  onChanged: _sending
                      ? null
                      : (value) => setState(() => _targetType = value!),
                ),
                if (_targetType == 'url') ...[
                  const SizedBox(height: 14),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextFormField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'رابط HTTPS',
                        hintText: 'https://...',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                      validator: (value) {
                        if (_targetType != 'url') return null;
                        final uri = Uri.tryParse(value?.trim() ?? '');
                        return uri?.scheme == 'https'
                            ? null
                            : 'أدخل رابط HTTPS صالحاً.';
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _publish,
          icon: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_rounded),
          label: Text(_sending ? 'جارٍ النشر...' : 'نشر الإشعار'),
        ),
      ],
    );
  }
}
