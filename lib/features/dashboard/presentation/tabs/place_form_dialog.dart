import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/geo/coordinates_parser.dart';
import '../../../../core/media/image_upload_mime.dart';

class PlaceFormDialog extends StatefulWidget {
  final Map<String, dynamic>? place;
  final TileProvider? tileProvider;

  const PlaceFormDialog({super.key, this.place, this.tileProvider});

  @override
  State<PlaceFormDialog> createState() => _PlaceFormDialogState();
}

enum _LocationMethod { coordinates, googleMaps, plusCode, map }

class _PlaceFormDialogState extends State<PlaceFormDialog> {
  static const _brandGreen = Color(0xFF193F38);
  static const _mapCenter = LatLng(33.3683, 6.8674);
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
  final _mapController = MapController();
  final List<XFile> _selectedImages = [];

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _phoneController;
  final TextEditingController _linkController = TextEditingController();

  String _mainCategory = '';
  String _status = 'منشور';
  bool _isLoading = false;
  bool _isResolvingLink = false;
  bool _mapReady = false;
  _LocationMethod _locationMethod = _LocationMethod.coordinates;
  GeoPoint? _selectedPoint;

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
    _selectedPoint = _pointFromFields();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _phoneController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage();
    if (images.isNotEmpty) setState(() => _selectedImages.addAll(images));
  }

  GeoPoint? _pointFromFields() {
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
    return GeoPoint(latitude, longitude);
  }

  void _setPoint(GeoPoint point) {
    _selectedPoint = point;
    _latController.text = point.latitude.toStringAsFixed(6);
    _lngController.text = point.longitude.toStringAsFixed(6);
    if (mounted) setState(() {});
    if (_mapReady) {
      _mapController.move(LatLng(point.latitude, point.longitude), 15);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.trim().isNotEmpty) {
      _linkController.text = text.trim();
      setState(() {});
    }
  }

  Future<void> _applyLocationInput() async {
    final input = _linkController.text.trim();
    if (input.isEmpty) return;
    setState(() => _isResolvingLink = true);
    try {
      final point = await CoordinatesParser.parse(input);
      if (!mounted) return;
      if (point == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'تعذر التعرف على الموقع. تأكد من الرابط، أو الصق الإحداثيات مباشرة مثل: 33.3448, 6.8422'),
        ));
        return;
      }
      _setPoint(point);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم تحديد الموقع بدقة من المصدر المُدخل.'),
      ));
    } finally {
      if (mounted) setState(() => _isResolvingLink = false);
    }
  }

  Future<void> _deletePlace() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا المعلم نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      await client.from('places').delete().eq('id', widget.place!['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ أثناء الحذف: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        final safeExt = ImageUploadMime.normalizedExtension(photo.name);
        final contentType = ImageUploadMime.contentTypeForExtension(safeExt);
        final fileName =
            'places/${DateTime.now().millisecondsSinceEpoch}.$safeExt';

        await client.storage.from('images').uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );
        imageUrl = client.storage.from('images').getPublicUrl(fileName);
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SizedBox(
            width: double.infinity,
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
                            _buildLocationPicker(),
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
          Expanded(
            child: Text(
              _isEditing ? 'تعديل المعلم' : 'إضافة معلم جديد',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
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
      onChanged: (_) {
        if (identical(controller, _latController) ||
            identical(controller, _lngController)) {
          _selectedPoint = _pointFromFields();
        }
        setState(() {});
      },
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
      isExpanded: true,
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

  Widget _buildLocationPicker() {
    final point = _selectedPoint ?? _pointFromFields();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD2E7DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('تحديد موقع المعلم',
              style:
                  TextStyle(fontWeight: FontWeight.w900, color: _brandGreen)),
          const SizedBox(height: 4),
          const Text(
            'اختر طريقة واحدة، وسيتم توحيد النتيجة في Latitude وLongitude قبل الحفظ.',
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLocationMethodChip(_LocationMethod.coordinates,
                  Icons.pin_drop_outlined, 'الإحداثيات'),
              _buildLocationMethodChip(_LocationMethod.googleMaps,
                  Icons.link_rounded, 'Google Maps'),
              _buildLocationMethodChip(_LocationMethod.plusCode,
                  Icons.add_location_alt_outlined, 'Plus Code'),
              _buildLocationMethodChip(
                  _LocationMethod.map, Icons.map_outlined, 'من الخريطة'),
            ],
          ),
          const SizedBox(height: 14),
          switch (_locationMethod) {
            _LocationMethod.coordinates => _buildCoordinateInputs(),
            _LocationMethod.googleMaps => _buildTextLocationInput(
                'الصق رابط Google Maps أو الرابط المختصر...',
                'يدعم maps.app.goo.gl و google.com/maps',
              ),
            _LocationMethod.plusCode => _buildTextLocationInput(
                'مثال: 9V83+WHF, El Oued',
                'يدعم Plus Code الكامل والمختصر عند معرفة منطقة الوادي',
              ),
            _LocationMethod.map => _buildInteractiveMap(point),
          },
          if (point != null) ...[
            const SizedBox(height: 12),
            _buildResolvedLocation(point),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationMethodChip(
    _LocationMethod method,
    IconData icon,
    String label,
  ) {
    final selected = _locationMethod == method;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _locationMethod = method),
      avatar:
          Icon(icon, size: 17, color: selected ? Colors.white : _brandGreen),
      label: Text(label),
      selectedColor: _brandGreen,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : _brandGreen,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
      side: BorderSide(color: selected ? _brandGreen : const Color(0xFFD2E7DF)),
    );
  }

  Widget _buildCoordinateInputs() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fields = [
          _buildField('Latitude', _latController, Icons.south_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true)),
          _buildField('Longitude', _lngController, Icons.east_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true)),
        ];
        return constraints.maxWidth < 380
            ? Column(
                children: [fields[0], const SizedBox(height: 10), fields[1]],
              )
            : Row(
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 10),
                  Expanded(child: fields[1]),
                ],
              );
      },
    );
  }

  Widget _buildTextLocationInput(String hint, String helper) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(helper,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _linkController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFD2E7DF)),
                  ),
                  prefixIcon: IconButton(
                    tooltip: 'لصق من الحافظة',
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    onPressed: _pasteFromClipboard,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _isResolvingLink ? null : _applyLocationInput,
              style: FilledButton.styleFrom(
                backgroundColor: _brandGreen,
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isResolvingLink
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('تحويل',
                      style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInteractiveMap(GeoPoint? point) {
    final center =
        point == null ? _mapCenter : LatLng(point.latitude, point.longitude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
            'انقر على الخريطة لاختيار موقع المعلم، ويمكنك النقر مرة أخرى لتغييره.',
            style: TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 235,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: point == null ? 11.5 : 15,
                onMapReady: () => _mapReady = true,
                onTap: (_, location) => _setPoint(
                  GeoPoint(location.latitude, location.longitude),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: widget.tileProvider == null
                      ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                      : 'assets/branding/icon.png',
                  tileProvider: widget.tileProvider,
                  userAgentPackageName: 'dz.ouedna.admin',
                ),
                if (point != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(point.latitude, point.longitude),
                        width: 46,
                        height: 46,
                        child: const Icon(Icons.location_on,
                            color: _brandGreen, size: 42),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResolvedLocation(GeoPoint point) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD2E7DF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF16805B), size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'الموقع المحدد\nLatitude: ${point.latitude.toStringAsFixed(6)}  •  Longitude: ${point.longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                  color: _brandGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w900),
            ),
          ),
        ],
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
                  child: FutureBuilder<Uint8List>(
                    future: _selectedImages[index].readAsBytes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasData) {
                        return Image.memory(snapshot.data!, fit: BoxFit.cover);
                      }
                      return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2));
                    },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final cancelButton = OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('إلغاء',
              style: TextStyle(fontWeight: FontWeight.w900)),
        );
        final deleteButton = FilledButton.tonal(
          onPressed: _isLoading ? null : _deletePlace,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade50,
            foregroundColor: Colors.red.shade700,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('حذف المعلم',
              style: TextStyle(fontWeight: FontWeight.w900)),
        );
        final saveButton = FilledButton(
          onPressed: _isLoading ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: _brandGreen,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        );
        final buttons = <Widget>[
          cancelButton,
          if (_isEditing) deleteButton,
          saveButton,
        ];
        final compact = constraints.maxWidth < 520;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < buttons.length; index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      buttons[index],
                    ],
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: cancelButton),
                    const SizedBox(width: 16),
                    if (_isEditing) ...[
                      Expanded(child: deleteButton),
                      const SizedBox(width: 12),
                    ],
                    Expanded(flex: 2, child: saveButton),
                  ],
                ),
        );
      },
    );
  }
}
