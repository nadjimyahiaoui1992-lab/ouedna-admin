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
  final _storeUrl = TextEditingController();
  final _directApkUrl = TextEditingController();
  final _sha256 = TextEditingController();
  final _notes = TextEditingController();
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
    _storeUrl.dispose();
    _directApkUrl.dispose();
    _sha256.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final row = await Supabase.instance.client
          .from('app_config')
          .select('latest_version, force_update, android_store_url, direct_apk_url, apk_sha256, release_notes')
          .eq('id', 1)
          .maybeSingle();
      if (row != null) {
        _version.text = row['latest_version']?.toString() ?? '';
        _forceUpdate = row['force_update'] == true;
        _storeUrl.text = row['android_store_url']?.toString() ?? '';
        _directApkUrl.text = row['direct_apk_url']?.toString() ?? '';
        _sha256.text = row['apk_sha256']?.toString() ?? '';
        _notes.text = row['release_notes']?.toString() ?? '';
      }
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('app_config').upsert({
        'id': 1,
        'latest_version': _version.text.trim(),
        'force_update': _forceUpdate,
        'android_store_url': _emptyToNull(_storeUrl.text),
        'direct_apk_url': _emptyToNull(_directApkUrl.text),
        'apk_sha256': _emptyToNull(_sha256.text)?.toLowerCase(),
        'release_notes': _emptyToNull(_notes.text),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر حفظ إعدادات التحديث: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) {
    final result = value.trim();
    return result.isEmpty ? null : result;
  }

  String? _urlValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    return uri != null && uri.scheme == 'https' ? null : 'استخدم رابط HTTPS صالحاً.';
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: SizedBox(
            width: 560,
            height: MediaQuery.sizeOf(context).height * .84,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFF193F38),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.system_update_alt_rounded, color: Colors.white),
                            SizedBox(width: 12),
                            Text('إدارة تحديث التطبيق', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('تحديث المتجر', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF193F38))),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _version,
                                  validator: (value) => value == null || value.trim().isEmpty ? 'الإصدار مطلوب.' : null,
                                  decoration: _input('رقم الإصدار الجديد، مثال: 1.6.0', Icons.numbers_rounded),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(controller: _storeUrl, validator: _urlValidator, keyboardType: TextInputType.url, decoration: _input('رابط صفحة Google Play (HTTPS)', Icons.storefront_outlined)),
                                const SizedBox(height: 22),
                                const Text('توزيع APK مباشر موثّق', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF193F38))),
                                const SizedBox(height: 6),
                                const Text('استخدمه فقط للإصدار المباشر خارج Google Play. لا تضع ملفاً دون بصمة SHA-256 مطابقة.', style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54)),
                                const SizedBox(height: 12),
                                TextFormField(controller: _directApkUrl, validator: _urlValidator, keyboardType: TextInputType.url, decoration: _input('رابط APK آمن (HTTPS)', Icons.download_outlined)),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _sha256,
                                  validator: (value) {
                                    final valueText = value?.trim() ?? '';
                                    if (_directApkUrl.text.trim().isEmpty && valueText.isEmpty) return null;
                                    return RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(valueText) ? null : 'أدخل بصمة SHA-256 من 64 رمزاً.';
                                  },
                                  decoration: _input('بصمة SHA-256 للـ APK', Icons.verified_user_outlined),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(controller: _notes, maxLines: 3, decoration: _input('ملاحظات الإصدار', Icons.notes_outlined)),
                                const SizedBox(height: 14),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  value: _forceUpdate,
                                  onChanged: (value) => setState(() => _forceUpdate = value),
                                  title: const Text('وضع التحديث المهم', style: TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: const Text('يعرض تنبيهاً واضحاً عند توفر الإصدار الجديد؛ لا يثبت أي شيء دون تأكيد المستخدم.'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('إلغاء'))),
                            const SizedBox(width: 12),
                            Expanded(child: FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات'))),
                          ],
                        ),
                      ),
                    ],
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
