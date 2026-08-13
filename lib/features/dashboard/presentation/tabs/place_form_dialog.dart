import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlaceFormDialog extends StatefulWidget {
  final Map<String, dynamic>? place;

  const PlaceFormDialog({super.key, this.place});

  @override
  State<PlaceFormDialog> createState() => _PlaceFormDialogState();
}

class _PlaceFormDialogState extends State<PlaceFormDialog> {
  static const _brandGreen = Color(0xFF193F38);

  static const Map<String, List<String>> _categories = {
    'معلم طبيعي': [],
    'معلم ديني': [],
    'معلم تراثي': [],
    'مرافق صحية': ['مستشفيات', 'مصحات خاصة', 'صيدليات'],
    'مطاعم': ['تقليدي', 'عصري', 'أكل سريع'],
    'فنادق ومنتجعات': ['فنادق', 'منتجعات', 'مراقد'],
    'أسواق': [],
    'متاجر ومحلات': [],
  };

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final List<XFile> _selectedImages = [];

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _phoneController;

  String _mainCategory = '';
  String _status = 'منشور';
  bool _isLoading = false;

  bool get _isEditing => widget.place != null;

  @override
  void initState() {
    super.initState();
    final p = widget.place;
    _nameController = TextEditingController(text: p?['name']?.toString() ?? '');
    _descriptionController =
        TextEditingController(text: p?['description']?.toString() ?? '');
    _addressController =
        TextEditingController(text: p?['address']?.toString() ?? '');
    _latController = TextEditingController(
        text: (p?['lat'] ?? p?['latitude'])?.toString() ?? '');
    _lngController = TextEditingController(
        text: (p?['lng'] ?? p?['longitude'])?.toString() ?? '');
    _phoneController =
        TextEditingController(text: p?['phone']?.toString() ?? '');

    _mainCategory = p?['main_category']?.toString() ?? _categories.keys.first;
    _status = p?['status']?.toString() ?? 'منشور';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage();
    if (images.isNotEmpty) setState(() => _selectedImages.addAll(images));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final data = {
        'name': _nameController.text.trim(),
        'main_category': _mainCategory,
        'description': _descriptionController.text.trim(),
        'address': _addressController.text.trim(),
        'lat': double.tryParse(_latController.text),
        'lng': double.tryParse(_lngController.text),
        'phone': _phoneController.text.trim(),
        'status': _status,
      };

      if (_isEditing) {
        await client.from('places').update(data).eq('id', widget.place!['id']);
      } else {
        await client.from('places').insert(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('المعلومات الأساسية'),
                        _buildField(
                            'اسم المعلم', _nameController, Icons.title_rounded,
                            required: true),
                        const SizedBox(height: 16),
                        _buildCategoryDropdown(),
                        const SizedBox(height: 16),
                        _buildField('الوصف', _descriptionController,
                            Icons.description_rounded,
                            maxLines: 3),
                        const SizedBox(height: 24),
                        _buildSectionTitle('الموقع والتواصل'),
                        _buildField('العنوان الكامل', _addressController,
                            Icons.location_on_rounded),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: _buildField('خط العرض', _latController,
                                    Icons.south_rounded,
                                    keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildField('خط الطول', _lngController,
                                    Icons.east_rounded,
                                    keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                            'رقم الهاتف', _phoneController, Icons.phone_rounded,
                            keyboardType: TextInputType.phone),
                        const SizedBox(height: 24),
                        _buildSectionTitle('الحالة والنشر'),
                        _buildStatusToggle(),
                        const SizedBox(height: 24),
                        _buildImagePicker(),
                      ],
                    ),
                  ),
                ),
              ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: _brandGreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.add_location_alt_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Text(
            _isEditing ? 'تعديل المعلم' : 'إضافة معلم جديد',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.w900, color: _brandGreen, fontSize: 14),
      ),
    );
  }

  Widget _buildField(
      String label, TextEditingController controller, IconData icon,
      {bool required = false, int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator:
          required ? (v) => v == null || v.isEmpty ? 'مطلوب' : null : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _mainCategory,
      decoration: InputDecoration(
        labelText: 'التصنيف الرئيسي',
        prefixIcon: const Icon(Icons.category_rounded, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
      ),
      items: _categories.keys
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (v) => setState(() => _mainCategory = v!),
    );
  }

  Widget _buildStatusToggle() {
    final statuses = ['منشور', 'قيد المراجعة', 'مسودة', 'مرفوض'];
    return Wrap(
      spacing: 8,
      children: statuses.map((s) {
        final isSelected = _status == s;
        return ChoiceChip(
          label: Text(s),
          selected: isSelected,
          onSelected: (v) => setState(() => _status = s),
          selectedColor: _brandGreen.withOpacity(0.1),
          labelStyle: TextStyle(
              color: isSelected ? _brandGreen : Colors.black54,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal),
        );
      }).toList(),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('الصور والوسائط'),
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFE2EAE5), style: BorderStyle.solid),
            ),
            child: const Column(
              children: [
                Icon(Icons.add_photo_alternate_rounded,
                    color: _brandGreen, size: 32),
                SizedBox(height: 8),
                Text('إضافة صور من المعرض',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _brandGreen,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => Container(
                width: 80,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2EAE5))),
                child: const Icon(Icons.image_rounded, color: Colors.grey),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('إلغاء',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: _isLoading ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _brandGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('حفظ المعلم',
                      style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadedPhoto {
  final String path;
  final String publicUrl;
  _UploadedPhoto({required this.path, required this.publicUrl});
}
