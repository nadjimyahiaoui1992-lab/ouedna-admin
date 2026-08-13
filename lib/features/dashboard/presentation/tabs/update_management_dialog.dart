import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdateManagementDialog extends StatefulWidget {
  const UpdateManagementDialog({super.key});

  @override
  State<UpdateManagementDialog> createState() => _UpdateManagementDialogState();
}

class _UpdateManagementDialogState extends State<UpdateManagementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _version = TextEditingController();
  final _directApkUrl = TextEditingController();
  final _sha256 = TextEditingController();
  final _notes = TextEditingController();
  final _notificationTitle = TextEditingController();
  final _notificationBody = TextEditingController();
  bool _forceUpdate = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _version.dispose();
    _directApkUrl.dispose();
    _sha256.dispose();
    _notes.dispose();
    _notificationTitle.dispose();
    _notificationBody.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final row = await Supabase.instance.client
          .from('app_config')
          .select(
            'latest_version, force_update, direct_apk_url, apk_sha256, release_notes',
          )
          .eq('id', 1)
          .maybeSingle();
      if (row != null) {
        _version.text = row['latest_version']?.toString() ?? '';
        _forceUpdate = row['force_update'] == true;
        _directApkUrl.text = row['direct_apk_url']?.toString() ?? '';
        _sha256.text = row['apk_sha256']?.toString() ?? '';
        _notes.text = row['release_notes']?.toString() ?? '';
      }
      _notificationTitle.text = 'يتوفر تحديث جديد لودنا';
      _notificationBody.text = _version.text.trim().isEmpty
          ? 'اضغط لفتح مركز التحديث وتثبيت الإصدار الجديد.'
          : 'الإصدار ${_version.text.trim()} جاهز الآن. اضغط لفتح مركز التحديث.';
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل إعدادات التحديث.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    final response = await Supabase.instance.client.functions.invoke(
      'save-release-config',
      body: {
        'latest_version': _version.text.trim(),
        'force_update': _forceUpdate,
        'direct_apk_url': _directApkUrl.text.trim(),
        'apk_sha256': _sha256.text.trim().toLowerCase(),
        'release_notes': _emptyToNull(_notes.text),
      },
    );
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final reason = data is Map ? data['error']?.toString() : null;
      throw StateError(reason ?? 'تعذر حفظ إعدادات الإصدار.');
    }
  }

  Future<void> _save({bool closeAfterSave = true}) async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await _persist();
      if (!mounted) return;
      if (closeAfterSave) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ إعدادات الإصدار المباشر.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ إعدادات التحديث: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndNotify() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final title = _notificationTitle.text.trim();
    final body = _notificationBody.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل عنواناً ونصاً لإشعار التحديث.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _persist();
      final result = await Supabase.instance.client.functions.invoke(
        'send-release-notification',
        body: {
          'release_version': _version.text.trim(),
          'title': title,
          'body': body,
        },
      );
      if (result.status < 200 || result.status >= 300) {
        final data = result.data;
        final reason = data is Map ? data['error']?.toString() : null;
        throw StateError(reason ?? 'تعذر إرسال الإشعار.');
      }
      final data = result.data;
      final sent = data is Map ? data['sent'] ?? 0 : 0;
      final failures = data is Map ? data['failures'] ?? 0 : 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failures == 0
                ? 'تم إرسال إشعار التحديث إلى $sent جهازاً.'
                : 'تم الإرسال إلى $sent جهازاً، وتعذر الإرسال إلى $failures جهازاً.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        final details = error.toString();
        final firebaseMissing =
            details.contains('push_provider_not_configured');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(
              firebaseMissing
                  ? 'تم حفظ الإصدار ونشره داخل مركز إشعارات وادنا. الإشعار الفوري غير مفعّل بعد لأن إعداد Firebase الخلفي غير مكتمل.'
                  : 'تم حفظ الإصدار، لكن تعذر إرسال الإشعار: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) {
    final result = value.trim();
    return result.isEmpty ? null : result;
  }

  String? _requiredUrlValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'رابط APK مطلوب.';
    final uri = Uri.tryParse(text);
    return uri != null && uri.scheme == 'https'
        ? null
        : 'استخدم رابط HTTPS صالحاً.';
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .88,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        const _DialogHeader(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _SectionTitle(
                                    icon: Icons.install_mobile_outlined,
                                    title: 'توزيع APK مباشر',
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'وادنا يوزّع خارج Google Play. ضع رابط ملف APK النهائي فقط، ثم أضف بصمة SHA-256 لحماية المستخدم قبل التثبيت.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.45,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _version,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.left,
                                    keyboardType: TextInputType.text,
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'رقم الإصدار مطلوب.'
                                            : null,
                                    decoration: _input(
                                      'رقم الإصدار، مثال: 1.7.3',
                                      Icons.numbers_rounded,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _directApkUrl,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.left,
                                    validator: _requiredUrlValidator,
                                    keyboardType: TextInputType.url,
                                    decoration: _input(
                                      'رابط تحميل APK الآمن (HTTPS)',
                                      Icons.download_for_offline_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _sha256,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.left,
                                    maxLength: 64,
                                    validator: (value) =>
                                        RegExp(r'^[a-fA-F0-9]{64}$')
                                                .hasMatch(value?.trim() ?? '')
                                            ? null
                                            : 'أدخل بصمة SHA-256 من 64 رمزاً.',
                                    decoration: _input(
                                      'بصمة SHA-256 للـ APK',
                                      Icons.verified_user_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _notes,
                                    maxLines: 3,
                                    decoration: _input(
                                      'ملاحظات الإصدار التي يراها المستخدم',
                                      Icons.notes_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SwitchListTile.adaptive(
                                    contentPadding: EdgeInsets.zero,
                                    value: _forceUpdate,
                                    onChanged: (value) =>
                                        setState(() => _forceUpdate = value),
                                    title: const Text(
                                      'تحديث مهم',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                    subtitle: const Text(
                                      'يمنع تأجيل نافذة التحديث، لكنه لا يثبت APK دون تأكيد المستخدم في أندرويد.',
                                    ),
                                  ),
                                  const Divider(height: 32),
                                  const _SectionTitle(
                                    icon: Icons.notifications_active_outlined,
                                    title: 'إشعار المستخدمين بالتحديث',
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'عند الحفظ والإرسال، يصل تنبيه للأجهزة التي وافقت على الإشعارات. الضغط عليه يفتح مركز التحديث داخل وادنا.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.45,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _notificationTitle,
                                    maxLength: 120,
                                    decoration: _input(
                                      'عنوان الإشعار',
                                      Icons.notifications_active_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _notificationBody,
                                    maxLength: 500,
                                    maxLines: 3,
                                    decoration: _input(
                                      'نص الإشعار',
                                      Icons.message_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _ResponsiveActions(
                          saving: _saving,
                          onCancel: () => Navigator.pop(context),
                          onSave: () => _save(closeAfterSave: false),
                          onSaveAndNotify: _saveAndNotify,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );

  InputDecoration _input(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      );
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF193F38),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: const Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'إدارة تحديث APK المباشر',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: const Color(0xFF193F38)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF193F38),
            ),
          ),
        ],
      );
}

class _ResponsiveActions extends StatelessWidget {
  const _ResponsiveActions({
    required this.saving,
    required this.onCancel,
    required this.onSave,
    required this.onSaveAndNotify,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onSaveAndNotify;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final notifyButton = FilledButton.icon(
                onPressed: saving ? null : onSaveAndNotify,
                icon: const Icon(Icons.send_rounded),
                label: Text(saving ? 'جارٍ الإرسال...' : 'حفظ وإرسال إشعار'),
              );
              final saveButton = OutlinedButton(
                onPressed: saving ? null : onSave,
                child: const Text('حفظ فقط'),
              );
              final cancelButton = TextButton(
                onPressed: saving ? null : onCancel,
                child: const Text('إلغاء'),
              );

              if (constraints.maxWidth < 440) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 48, child: notifyButton),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: saveButton),
                        const SizedBox(width: 8),
                        Expanded(child: cancelButton),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: cancelButton),
                  const SizedBox(width: 8),
                  Expanded(child: saveButton),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: notifyButton),
                ],
              );
            },
          ),
        ),
      );
}
