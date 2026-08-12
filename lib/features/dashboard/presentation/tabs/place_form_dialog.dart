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
  static const _gold = Color(0xFFD9A441);
  static const _defaultLat = 33.3683;
  static const _defaultLng = 6.8674;

  static const Map<String, List<String>> _categories = {
    'معلم طبيعي': [],
    'معلم ديني': [],
    'معلم تراثي': [],
    'مرافق صحية': [
      'مستشفيات',
      'مصحات خاصة',
      'مركز التصوير الإشعاعي',
      'أطباء مختصون وعيادات خاصة',
      'مراكز التأهيل',
      'صيدليات',
      'شبه صيدلي',
    ],
    'مطاعم': [
      'تقليدي',
      'عصري',
      'مختلط',
      'أكل سريع',
      'أكلات شعبية',
      'مقاهي',
    ],
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
  late final TextEditingController _districtController;
  late final TextEditingController _municipalityController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _mapLinkController;
  late final TextEditingController _phoneController;
  late final TextEditingController _websiteController;
  late final TextEditingController _facebookController;
  late final TextEditingController _instagramController;
  late final TextEditingController _openingHoursController;

  String _mainCategory = '';
  String _subCategory = '';
  String _status = 'منشور';
  bool _isLoading = false;

  bool get _isEditing => widget.place != null;
  List<String> get _subCategories => _categories[_mainCategory] ?? const [];

  @override
  void initState() {
    super.initState();
    final place = widget.place;

    _nameController = TextEditingController(text: _stringValue(place?['name']));
    _descriptionController =
        TextEditingController(text: _stringValue(place?['description']));
    _addressController =
        TextEditingController(text: _stringValue(place?['address']));
    _districtController =
        TextEditingController(text: _stringValue(place?['district']));
    _municipalityController =
        TextEditingController(text: _stringValue(place?['municipality']));
    _latController = TextEditingController(
      text: _coordinateValue(place?['lat'] ?? place?['latitude']),
    );
    _lngController = TextEditingController(
      text: _coordinateValue(place?['lng'] ?? place?['longitude']),
    );
    _mapLinkController =
        TextEditingController(text: _stringValue(place?['map_link']));
    _phoneController =
        TextEditingController(text: _stringValue(place?['phone']));
    _websiteController =
        TextEditingController(text: _stringValue(place?['website']));
    _facebookController =
        TextEditingController(text: _stringValue(place?['facebook']));
    _instagramController =
        TextEditingController(text: _stringValue(place?['instagram']));
    _openingHoursController =
        TextEditingController(text: _stringValue(place?['opening_hours']));

    final existingCategory =
        _stringValue(place?['main_category'] ?? place?['category']);
    _mainCategory = _categories.containsKey(existingCategory)
        ? existingCategory
        : _categories.keys.first;
    final existingSubCategory = _stringValue(place?['sub_category']);
    _subCategory = _categories[_mainCategory]!.contains(existingSubCategory)
        ? existingSubCategory
        : '';
    _status = _stringValue(place?['status']).isEmpty
        ? 'منشور'
        : _stringValue(place?['status']);
  }

  String _stringValue(dynamic value) => value?.toString().trim() ?? '';

  String _coordinateValue(dynamic value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    return value.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _districtController.dispose();
    _municipalityController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _mapLinkController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _openingHoursController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 88,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (images.isEmpty || !mounted) return;
      setState(() => _selectedImages.addAll(images));
    } catch (_) {
      _showError('تعذر فتح معرض الصور. يرجى التحقق من أذونات الصور.');
    }
  }

  Future<List<_UploadedPhoto>> _uploadSelectedImages() async {
    if (_selectedImages.isEmpty) return const [];

    final storage = Supabase.instance.client.storage.from('images');
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final uploaded = <_UploadedPhoto>[];

    try {
      for (var index = 0; index < _selectedImages.length; index++) {
        final file = _selectedImages[index];
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          throw StateError('ملف الصورة فارغ.');
        }

        final extension = _safeExtension(file.name);
        final path = 'places/$timestamp-$index.$extension';
        await storage.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(extension),
            upsert: false,
          ),
        );
        uploaded.add(
          _UploadedPhoto(
            path: path,
            publicUrl: storage.getPublicUrl(path),
          ),
        );
      }
      return uploaded;
    } catch (_) {
      if (uploaded.isNotEmpty) {
        await storage.remove(uploaded.map((photo) => photo.path).toList());
      }
      rethrow;
    }
  }

  String _safeExtension(String filename) {
    final extension =
        filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
    return {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? extension
        : 'jpg';
  }

  String _contentTypeFor(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<int> _nextGallerySortOrder(int placeId) async {
    final rows = await Supabase.instance.client
        .from('gallery')
        .select('sort_order')
        .eq('place_id', placeId);
    final orders = (rows as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['sort_order'])
        .whereType<num>();
    if (orders.isEmpty) return 0;
    return orders
            .reduce((largest, current) => current > largest ? current : largest)
            .toInt() +
        1;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final client = Supabase.instance.client;
    List<_UploadedPhoto> uploaded = const [];
    int? createdPlaceId;

    try {
      uploaded = await _uploadSelectedImages();
      final existingImageUrl = _stringValue(widget.place?['image_url']);
      final lat = _latController.text.trim().isEmpty
          ? null
          : double.parse(_latController.text.trim());
      final lng = _lngController.text.trim().isEmpty
          ? null
          : double.parse(_lngController.text.trim());

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'main_category': _mainCategory,
        'sub_category': _subCategory.isEmpty ? null : _subCategory,
        'description': _nullableText(_descriptionController),
        'address': _nullableText(_addressController),
        'district': _nullableText(_districtController),
        'municipality': _nullableText(_municipalityController),
        'lat': lat,
        'lng': lng,
        'map_link': _nullableText(_mapLinkController),
        'phone': _nullableText(_phoneController),
        'website': _nullableText(_websiteController),
        'facebook': _nullableText(_facebookController),
        'instagram': _nullableText(_instagramController),
        'opening_hours': _nullableText(_openingHoursController),
        'status': _status,
        // L’URL de couverture n’est modifiée qu’après l’ajout réussi des
        // nouvelles entrées de galerie : aucune fiche ne pointe vers un
        // fichier qui aurait été nettoyé après un échec intermédiaire.
        'image_url': existingImageUrl.isEmpty ? null : existingImageUrl,
      };

      final Map<String, dynamic> savedPlace;
      if (_isEditing) {
        savedPlace = await client
            .from('places')
            .update(data)
            .eq('id', widget.place!['id'])
            .select()
            .single();
      } else {
        savedPlace = await client.from('places').insert(data).select().single();
        createdPlaceId = (savedPlace['id'] as num).toInt();
      }

      if (uploaded.isNotEmpty) {
        final placeId = (savedPlace['id'] as num).toInt();
        final startSortOrder = await _nextGallerySortOrder(placeId);

        // Il ne peut y avoir qu’une seule couverture active : la première
        // nouvelle image prend cette fonction et les images existantes restent
        // dans la galerie sans être supprimées.
        await client
            .from('gallery')
            .update({'is_cover': false}).eq('place_id', placeId);
        await client.from('gallery').insert(
              uploaded
                  .asMap()
                  .entries
                  .map(
                    (entry) => {
                      'place_id': placeId,
                      'image_url': entry.value.publicUrl,
                      'is_cover': entry.key == 0,
                      'sort_order': startSortOrder + entry.key,
                    },
                  )
                  .toList(),
            );
        await client
            .from('places')
            .update({'image_url': uploaded.first.publicUrl}).eq('id', placeId);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      // Une création qui n’a pas atteint toutes les étapes (fiche, galerie,
      // image de couverture) est supprimée entièrement au lieu de laisser une
      // donnée partielle exposée dans l’application des visiteurs.
      if (createdPlaceId != null) {
        try {
          await client.from('gallery').delete().eq('place_id', createdPlaceId);
          await client.from('places').delete().eq('id', createdPlaceId);
        } catch (_) {
          // L’erreur principale reste prioritaire pour l’administrateur.
        }
      }
      if (uploaded.isNotEmpty) {
        try {
          await client.storage.from('images').remove(
                uploaded.map((photo) => photo.path).toList(),
              );
        } catch (_) {
          // Ne jamais masquer l’erreur de sauvegarde par une erreur de purge.
        }
      }
      if (mounted) {
        _showError(
            'خطأ أثناء الحفظ. تحقق من الاتصال والصلاحيات ثم أعد المحاولة.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;

  String? _coordinateValidator(String? value, bool isLatitude) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final coordinate = double.tryParse(text);
    if (coordinate == null) return 'يرجى إدخال رقم صحيح';
    final valid = isLatitude
        ? coordinate >= -90 && coordinate <= 90
        : coordinate >= -180 && coordinate <= 180;
    return valid ? null : 'الإحداثي خارج النطاق الصحيح';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existingImage = _stringValue(widget.place?['image_url']);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _brandGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.place_outlined, color: _brandGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isEditing ? 'تعديل المعلم' : 'إضافة معلم جديد',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle(
                      'المعلومات الأساسية', Icons.account_balance_outlined),
                  _textField(
                    controller: _nameController,
                    label: 'اسم المعلم *',
                    icon: Icons.title_outlined,
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _mainCategory,
                    isExpanded: true,
                    decoration: _decoration(
                        'التصنيف الرئيسي *', Icons.category_outlined),
                    items: _categories.keys
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child:
                                Text(category, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _mainCategory = value;
                              _subCategory = '';
                            });
                          },
                  ),
                  if (_subCategories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _subCategory.isEmpty ? null : _subCategory,
                      isExpanded: true,
                      decoration: _decoration(
                          'التصنيف الفرعي', Icons.account_tree_outlined),
                      items: _subCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: _isLoading
                          ? null
                          : (value) =>
                              setState(() => _subCategory = value ?? ''),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _textField(
                    controller: _descriptionController,
                    label: 'وصف المعلم',
                    icon: Icons.notes_outlined,
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('الموقع والخريطة', Icons.map_outlined),
                  _textField(
                    controller: _addressController,
                    label: 'العنوان',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 12),
                  _adaptivePair(
                    _textField(
                      controller: _districtController,
                      label: 'الحي / المنطقة',
                      icon: Icons.location_city_outlined,
                    ),
                    _textField(
                      controller: _municipalityController,
                      label: 'البلدية',
                      icon: Icons.apartment_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _adaptivePair(
                    _textField(
                      controller: _latController,
                      label: 'خط العرض',
                      icon: Icons.explore_outlined,
                      helperText: 'مثال: ${_defaultLat.toStringAsFixed(4)}',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (value) => _coordinateValidator(value, true),
                    ),
                    _textField(
                      controller: _lngController,
                      label: 'خط الطول',
                      icon: Icons.explore_outlined,
                      helperText: 'مثال: ${_defaultLng.toStringAsFixed(4)}',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (value) => _coordinateValidator(value, false),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _mapLinkController,
                    label: 'رابط الخريطة',
                    icon: Icons.link_outlined,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle(
                      'التواصل وساعات العمل', Icons.contact_phone_outlined),
                  _textField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _websiteController,
                    label: 'الموقع الإلكتروني',
                    icon: Icons.language_outlined,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  _adaptivePair(
                    _textField(
                      controller: _facebookController,
                      label: 'رابط فيسبوك',
                      icon: Icons.facebook_outlined,
                      keyboardType: TextInputType.url,
                    ),
                    _textField(
                      controller: _instagramController,
                      label: 'رابط إنستغرام',
                      icon: Icons.camera_alt_outlined,
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _openingHoursController,
                    label: 'ساعات العمل',
                    icon: Icons.schedule_outlined,
                    helperText: 'مثال: 08:00 - 22:00',
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('الصور والنشر', Icons.photo_library_outlined),
                  if (existingImage.isNotEmpty && _selectedImages.isEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        existingImage,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pickImages,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: _brandGreen,
                      side: const BorderSide(color: _gold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _selectedImages.isEmpty
                          ? 'إضافة صور للمعلم'
                          : 'إضافة صور أخرى',
                    ),
                  ),
                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'سيتم حفظ ${_selectedImages.length} صورة في معرض المعلم، وتُستخدم الأولى كصورة غلاف.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _brandGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) => _imagePreview(index),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration:
                        _decoration('حالة المعلم', Icons.visibility_outlined),
                    items: const [
                      DropdownMenuItem(
                        value: 'منشور',
                        child: Text('منشور — يظهر للزوار فوراً'),
                      ),
                      DropdownMenuItem(
                        value: 'قيد المراجعة',
                        child: Text('قيد المراجعة — بانتظار اعتماد الإدارة'),
                      ),
                      DropdownMenuItem(
                        value: 'مسودة',
                        child: Text('مسودة — مخفي عن الزوار'),
                      ),
                      DropdownMenuItem(
                        value: 'مرفوض',
                        child: Text('مرفوض — لا يظهر للزوار'),
                      ),
                    ],
                    onChanged: _isLoading
                        ? null
                        : (value) => setState(() => _status = value ?? 'منشور'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _brandGreen,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: _isLoading ? null : _save,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isLoading ? 'جارٍ الحفظ...' : 'حفظ المعلم'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _gold),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: _brandGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _brandGreen.withOpacity(0.2)),
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? helperText,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        textInputAction:
            maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        decoration: _decoration(label, icon).copyWith(helperText: helperText),
      );

  Widget _adaptivePair(Widget first, Widget second) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 430) {
            return Column(
              children: [first, const SizedBox(height: 12), second],
            );
          }
          return Row(
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
            ],
          );
        },
      );

  Widget _imagePreview(int index) {
    final image = _selectedImages[index];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FutureBuilder<Uint8List>(
            future: image.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  width: 92,
                  height: 92,
                  color: _brandGreen.withOpacity(0.08),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                );
              }
              return Image.memory(
                snapshot.data!,
                width: 92,
                height: 92,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading
                  ? null
                  : () => setState(() => _selectedImages.removeAt(index)),
              customBorder: const CircleBorder(),
              child: const CircleAvatar(
                radius: 13,
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ),
        if (index == 0)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _brandGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'الغلاف',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}

class _UploadedPhoto {
  final String path;
  final String publicUrl;

  const _UploadedPhoto({required this.path, required this.publicUrl});
}
