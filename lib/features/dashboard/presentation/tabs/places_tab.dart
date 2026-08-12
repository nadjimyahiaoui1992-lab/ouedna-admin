import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'place_form_dialog.dart';

class PlacesTab extends StatefulWidget {
  const PlacesTab({super.key});

  @override
  State<PlacesTab> createState() => _PlacesTabState();
}

class _PlacesTabState extends State<PlacesTab> {
  late Future<List<Map<String, dynamic>>> _placesFuture;
  String? _statusFilter;
  RealtimeChannel? _placesChannel;
  Timer? _reloadDebounce;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _subscribeToPlaceChanges();
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    if (_placesChannel != null) {
      Supabase.instance.client.removeChannel(_placesChannel!);
    }
    super.dispose();
  }

  void _subscribeToPlaceChanges() {
    _placesChannel = Supabase.instance.client
        .channel('souf-admin-places-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'places',
          callback: (_) => _queueRefresh(),
        )
        .subscribe();
  }

  void _queueRefresh() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(_loadPlaces);
    });
  }

  void _loadPlaces() {
    _placesFuture = Supabase.instance.client
        .from('places')
        .select()
        .order('created_at', ascending: false);
  }

  Future<void> _refresh() async {
    setState(_loadPlaces);
    await _placesFuture;
  }

  Future<void> _deletePlace(String id) async {
    try {
      await Supabase.instance.client.from('places').delete().eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المعلم بنجاح')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حذف المعلم: $error')),
      );
    }
  }

  Future<void> _updateStatus(
    Map<String, dynamic> place,
    String status,
  ) async {
    try {
      await Supabase.instance.client
          .from('places')
          .update({'status': status}).eq('id', place['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'منشور'
                ? 'تم اعتماد المعلم ونشره في الموقع والتطبيق.'
                : 'تم تحديث حالة المعلم إلى $status.',
          ),
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث حالة المعلم: $error')),
      );
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المعلم؟'),
        content: Text('سيتم حذف «${place['name'] ?? 'هذا المعلم'}» نهائياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deletePlace(place['id'].toString());
  }

  void _openPlaceForm([Map<String, dynamic>? place]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PlaceFormDialog(place: place),
    );
    if (result == true && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _placesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text('تعذر تحميل المعالم: ${snapshot.error}'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allPlaces = snapshot.data ?? const <Map<String, dynamic>>[];
          final pendingCount = allPlaces
              .where((place) => place['status'] == 'قيد المراجعة')
              .length;
          final places = _statusFilter == null
              ? allPlaces
              : allPlaces
                  .where((place) => place['status'] == _statusFilter)
                  .toList(growable: false);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
              children: [
                _ModerationBanner(
                  pendingCount: pendingCount,
                  onReview: () =>
                      setState(() => _statusFilter = 'قيد المراجعة'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusFilterChip(
                      label: 'الكل',
                      selected: _statusFilter == null,
                      onSelected: () => setState(() => _statusFilter = null),
                    ),
                    _StatusFilterChip(
                      label: 'قيد المراجعة',
                      selected: _statusFilter == 'قيد المراجعة',
                      badge: pendingCount,
                      onSelected: () =>
                          setState(() => _statusFilter = 'قيد المراجعة'),
                    ),
                    _StatusFilterChip(
                      label: 'منشور',
                      selected: _statusFilter == 'منشور',
                      onSelected: () => setState(() => _statusFilter = 'منشور'),
                    ),
                    _StatusFilterChip(
                      label: 'مسودة',
                      selected: _statusFilter == 'مسودة',
                      onSelected: () => setState(() => _statusFilter = 'مسودة'),
                    ),
                    _StatusFilterChip(
                      label: 'مرفوض',
                      selected: _statusFilter == 'مرفوض',
                      onSelected: () => setState(() => _statusFilter = 'مرفوض'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (places.isEmpty)
                  _EmptyPlacesState(isFiltered: _statusFilter != null)
                else
                  ...places.map(
                    (place) => _PlaceModerationCard(
                      place: place,
                      onEdit: () => _openPlaceForm(place),
                      onPublish: () => _updateStatus(place, 'منشور'),
                      onReject: () => _updateStatus(place, 'مرفوض'),
                      onDelete: () => _confirmDelete(place),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF193F38),
        foregroundColor: Colors.white,
        onPressed: () => _openPlaceForm(),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('إضافة معلم جديد'),
      ),
    );
  }
}

class _ModerationBanner extends StatelessWidget {
  const _ModerationBanner({required this.pendingCount, required this.onReview});

  final int pendingCount;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined, size: 34, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مراجعة اقتراحات الزوار',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  pendingCount == 0
                      ? 'لا توجد اقتراحات معلّقة حالياً.'
                      : 'لديك $pendingCount اقتراحاً بانتظار الاعتماد.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          if (pendingCount > 0)
            TextButton(
              onPressed: onReview,
              child: const Text('مراجعة'),
            ),
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final int? badge;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(badge == null || badge == 0 ? label : '$label ($badge)'),
        selected: selected,
        onSelected: (_) => onSelected(),
      );
}

class _PlaceModerationCard extends StatelessWidget {
  const _PlaceModerationCard({
    required this.place,
    required this.onEdit,
    required this.onPublish,
    required this.onReject,
    required this.onDelete,
  });

  final Map<String, dynamic> place;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = place['status']?.toString() ?? 'منشور';
    final isPending = status == 'قيد المراجعة';
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlaceImage(imageUrl: place['image_url']?.toString()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place['name']?.toString() ?? 'بدون اسم',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          place['main_category'],
                          place['municipality'] ?? place['address'],
                        ]
                            .whereType<String>()
                            .where((text) => text.isNotEmpty)
                            .join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      _StatusBadge(status: status),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'تعديل',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'حذف',
                  color: scheme.error,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('رفض'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onPublish,
                      icon: const Icon(Icons.publish_rounded),
                      label: const Text('اعتماد ونشر'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlaceImage extends StatelessWidget {
  const _PlaceImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 64,
          height: 64,
          child: imageUrl == null || imageUrl!.isEmpty
              ? const ColoredBox(
                  color: Color(0x22193F38),
                  child: Icon(Icons.image_not_supported_outlined),
                )
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0x22193F38),
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'منشور' => Colors.green,
      'قيد المراجعة' => Colors.orange,
      'مرفوض' => Colors.red,
      _ => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style:
            TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _EmptyPlacesState extends StatelessWidget {
  const _EmptyPlacesState({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 72),
        child: Column(
          children: [
            const Icon(Icons.location_off_outlined, size: 54),
            const SizedBox(height: 12),
            Text(isFiltered
                ? 'لا توجد معالم بهذه الحالة.'
                : 'لا توجد معالم مضافة بعد.'),
          ],
        ),
      );
}
