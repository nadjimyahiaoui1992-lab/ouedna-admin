import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
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
      text: (p?['lat'] ?? p?['latitude'])?.toString() ?? '',
    );
    _lngController = TextEditingController(
      text: (p?['lng'] ?? p?['longitude'])?.toString() ?? '',
    );
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

  LatLng? _pointFromFields() {
    final latitude =
        double.tryParse(_latController.text.trim().replaceAll(',', '.'));
    final longitude =
        double.tryParse(_lngController.text.trim().replaceAll(',', '.'));
    if (latitude == null || longitude == null) return null;
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  void _setPoint(LatLng point) {
    _latController.text = point.latitude.toStringAsFixed(6);
    _lngController.text = point.longitude.toStringAsFixed(6);
    setState(() {});
  }

  Future<void> _openMapPicker() async {
    final selected = await showDialog<LatLng>(
      context: context,
      builder: (_) => _MapPickerDialog(initialPoint: _pointFromFields()),
    );
    if (selected != null) _setPoint(selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final point = _pointFromFields();
    if ((_latController.text.trim().isNotEmpty ||
            _lngController.text.trim().isNotEmpty) &&
        point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'تحقق من صحة خط العرض وخط الطول أو اختر الموقع من الخريطة.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      String? imageUrl = widget.place?['image_url']?.toString();

      if (_selectedImages.isNotEmpty) {
        final photo = _selectedImages.first;
        final bytes = await photo.readAsBytes();
        final ext = photo.name.split('.').last.toLowerCase();
        final safeExt = {'png', 'webp', 'jpg', 'jpeg'}.contains(ext) ? ext : 'jpg';
        final fileName = 'places/${DateTime.now().millisecondsSinceEpoch}.$safeExt';

        await client.storage.from('archive-images').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$safeExt', upsert: true),
        );
        imageUrl = client.storage.from('archive-images').getPublicUrl(fileName);
      }

      final data = {
        'name': _nameController.text.trim(),
        'main_category': _mainCategory,
        'description': _descriptionController.text.trim(),
        'address': _addressController.text.trim(),
        'lat': point?.latitude,
        'lng': point?.longitude,
        'phone': _phoneController.text.trim(),
        'status': _status,
        if (imageUrl != null) 'image_url': imageUrl,
      };

      if (_isEditing) {
        await client.from('places').update(data).eq('id', widget.place!['id']);
      } else {
        await client.from('places').insert(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        backgroundColor: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SizedBox(
          width: 560,
          height: MediaQuery.sizeOf(context).height * .88,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionTitle('المعلومات الأساسية'),
                          _buildField('اسم المعلم', _nameController,
                              Icons.title_rounded,
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
                          const SizedBox(height: 12),
                          _buildMapPickerCard(),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) =>
                                constraints.maxWidth < 360
                                    ? Column(
                                        children: [
                                          _buildField(
                                              'خط العرض',
                                              _latController,
                                              Icons.south_rounded,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true, signed: true)),
                                          const SizedBox(height: 12),
                                          _buildField(
                                              'خط الطول',
                                              _lngController,
                                              Icons.east_rounded,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true, signed: true)),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                              child: _buildField(
                                                  'خط العرض',
                                                  _latController,
                                                  Icons.south_rounded,
                                                  keyboardType:
                                                      const TextInputType
                                                          .numberWithOptions(
                                                          decimal: true,
                                                          signed: true))),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child: _buildField(
                                                  'خط الطول',
                                                  _lngController,
                                                  Icons.east_rounded,
                                                  keyboardType:
                                                      const TextInputType
                                                          .numberWithOptions(
                                                          decimal: true,
                                                          signed: true))),
                                        ],
                                      ),
                          ),
                          if (_pointFromFields() != null) ...[
                            const SizedBox(height: 8),
                            const Text('تم تحديد موقع المعلم بدقة على الخريطة.',
                                style: TextStyle(
                                    color: _brandGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ],
                          const SizedBox(height: 16),
                          _buildField('رقم الهاتف', _phoneController,
                              Icons.phone_rounded,
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
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
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
          fontWeight: FontWeight.w900,
          color: _brandGreen,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
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
          borderSide: BorderSide.none,
        ),
      ),
      items: _categories.keys
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (v) => setState(() => _mainCategory = v!),
    );
  }

  Widget _buildMapPickerCard() {
    final point = _pointFromFields();
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('حدد موقع المعلم على الخريطة',
            style: TextStyle(fontWeight: FontWeight.w900, color: _brandGreen)),
        const SizedBox(height: 4),
        Text(
          point == null
              ? 'اضغط على الخريطة ثم ضع الدبوس بدقة.'
              : '${point.latitude.toStringAsFixed(5)}، ${point.longitude.toStringAsFixed(5)}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
    final action = FilledButton.icon(
      onPressed: _openMapPicker,
      icon: const Icon(Icons.map_outlined, size: 18),
      label: Text(point == null ? 'فتح الخريطة' : 'تعديل'),
      style: FilledButton.styleFrom(
          backgroundColor: _brandGreen,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11)),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6F3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD2E7DF)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 385
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                            color: _brandGreen,
                            borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.pin_drop_rounded,
                            color: Colors.white)),
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ]),
                  const SizedBox(height: 12),
                  action,
                ],
              )
            : Row(
                children: [
                  Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: _brandGreen,
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.pin_drop_rounded,
                          color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(child: details),
                  const SizedBox(width: 8),
                  action,
                ],
              ),
      ),
    );
  }

  Widget _buildStatusToggle() {
    final statuses = ['منشور', 'قيد المراجعة', 'مسودة', 'مرفوض'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((s) {
        final isSelected = _status == s;
        return ChoiceChip(
          label: Text(s),
          selected: isSelected,
          onSelected: (_) => setState(() => _status = s),
          selectedColor: _brandGreen.withOpacity(0.1),
          labelStyle: TextStyle(
            color: isSelected ? _brandGreen : Colors.black54,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
          ),
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
              border: Border.all(color: const Color(0xFFE2EAE5)),
            ),
            child: const Column(
              children: [
                Icon(Icons.add_photo_alternate_rounded,
                    color: _brandGreen, size: 32),
                SizedBox(height: 8),
                Text(
                  'إضافة صور من المعرض',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _brandGreen,
                    fontSize: 13,
                  ),
                ),
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
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2EAE5)),
                  ),
                  child: Image.memory(
                    _selectedImages[index].bytesSync(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: Colors.grey),
                  ),
                ),
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
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('حفظ المعلم',
                      style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPickerDialog extends StatefulWidget {
  const _MapPickerDialog({this.initialPoint});
  final LatLng? initialPoint;

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  static const _brandGreen = Color(0xFF193F38);
  static const _defaultElOued = LatLng(33.3683, 6.8674);
  late LatLng _selectedPoint;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint ?? _defaultElOued;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.min(size.width - 28, 760.0);
    final height = math.min(size.height - 80, 650.0);
    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Container(
              color: _brandGreen,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.pin_drop_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'اختيار موقع المعلم',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: _selectedPoint,
                      initialZoom: 13.5,
                      onTap: (_, point) =>
                          setState(() => _selectedPoint = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.ouedna.admin.v2',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedPoint,
                            width: 54,
                            height: 64,
                            child: const Column(
                              children: [
                                Icon(Icons.location_on_rounded,
                                    color: Colors.red, size: 48),
                                SizedBox(height: 1),
                                Expanded(child: SizedBox()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: Colors.white.withOpacity(0.94),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Text(
                          'اضغط على أي نقطة في الخريطة لتحريك الدبوس، ثم أكد الموقع.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الإحداثيات المحددة',
                            style:
                                TextStyle(fontSize: 11, color: Colors.black54)),
                        const SizedBox(height: 3),
                        Text(
                          '${_selectedPoint.latitude.toStringAsFixed(6)}، ${_selectedPoint.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                              color: _brandGreen, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _selectedPoint),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('تأكيد الموقع'),
                    style: FilledButton.styleFrom(backgroundColor: _brandGreen),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
