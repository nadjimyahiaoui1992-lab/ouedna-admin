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
  final _searchController = TextEditingController();
  String _searchQuery = '';
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
    _searchController.dispose();
    if (_placesChannel != null) {
      Supabase.instance.client.removeChannel(_placesChannel!);
    }
    super.dispose();
  }

  void _subscribeToPlaceChanges() {
    _placesChannel = Supabase.instance.client
        .channel('souf-admin-places-live')
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
    _reloadDebounce = Timer(const Duration(milliseconds: 500), () {
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

  Future<void> _updateStatus(Map<String, dynamic> place, String status) async {
    try {
      await Supabase.instance.client
          .from('places')
          .update({'status': status}).eq('id', place['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'منشور'
              ? 'تم النشر بنجاح'
              : 'تم تحديث الحالة إلى $status'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: status == 'منشور' ? Colors.green : Colors.black87,
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _deletePlace(Map<String, dynamic> place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المعلم'),
          content: Text(
            'هل تريد حذف «${place['name'] ?? 'هذا المعلم'}» نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('حذف نهائي'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await Supabase.instance.client
          .from('places')
          .delete()
          .eq('id', place['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المعلم بنجاح.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حذف المعلم: $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openPlaceForm([Map<String, dynamic>? place]) async {
    final result = await showDialog<bool>(
      context: context,
      useSafeArea: false,
      builder: (context) => PlaceFormDialog(place: place),
    );
    if (result == true && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _placesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF193F38)));
          }

          final allPlaces = snapshot.data ?? [];
          final pendingCount =
              allPlaces.where((p) => p['status'] == 'قيد المراجعة').length;
          final filteredPlaces = allPlaces.where((place) {
            final matchesStatus =
                _statusFilter == null || place['status'] == _statusFilter;
            if (!matchesStatus || _searchQuery.isEmpty) return matchesStatus;
            final haystack = [
              place['name'],
              place['main_category'],
              place['sub_category'],
              place['municipality'],
              place['district'],
              place['address'],
            ].whereType<String>().join(' ').toLowerCase();
            return haystack.contains(_searchQuery);
          }).toList(growable: false);

          return Column(
            children: [
              _buildFilterBar(pendingCount),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: const Color(0xFF193F38),
                  child: filteredPlaces.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: filteredPlaces.length,
                          itemBuilder: (context, index) => _PlaceCard(
                            place: filteredPlaces[index],
                            onEdit: () => _openPlaceForm(filteredPlaces[index]),
                            onDelete: () => _deletePlace(filteredPlaces[index]),
                            onApprove: () =>
                                _updateStatus(filteredPlaces[index], 'منشور'),
                            onReject: () =>
                                _updateStatus(filteredPlaces[index], 'مرفوض'),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPlaceForm(),
        backgroundColor: const Color(0xFF193F38),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة معلم',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildFilterBar(int pendingCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() {
              _searchQuery = value.trim().toLowerCase();
            }),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو التصنيف أو البلدية...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2EAE5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2EAE5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF193F38)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'الكل',
                  count: null,
                  selected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'قيد المراجعة',
                  count: pendingCount,
                  selected: _statusFilter == 'قيد المراجعة',
                  color: const Color(0xFFD97706),
                  onTap: () => setState(() => _statusFilter = 'قيد المراجعة'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'منشور',
                  count: null,
                  selected: _statusFilter == 'منشور',
                  color: Colors.green,
                  onTap: () => setState(() => _statusFilter = 'منشور'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'مرفوض',
                  count: null,
                  selected: _statusFilter == 'مرفوض',
                  color: Colors.red,
                  onTap: () => setState(() => _statusFilter = 'مرفوض'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        const Icon(Icons.location_off_rounded,
            size: 64, color: Color(0xFFCBD5E1)),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _searchQuery.isEmpty
                ? 'لا توجد معالم حالياً'
                : 'لا توجد نتائج مطابقة',
            style: const TextStyle(
                fontWeight: FontWeight.w900, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
    this.color = const Color(0xFF193F38),
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : const Color(0xFFE2EAE5)),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF64748B),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.2)
                      : color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: selected ? Colors.white : color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.onEdit,
    required this.onDelete,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> place;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final status = place['status']?.toString() ?? 'منشور';
    final isPending = status == 'قيد المراجعة';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EAE5)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildImage(place['image_url']),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place['name'] ?? 'بدون اسم',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFF193F38)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${place['main_category'] ?? 'تصنيف عام'} • ${place['municipality'] ?? 'غير محدد'}',
                        style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusBadge(status),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'تعديل المعلم',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_note_rounded,
                          color: Color(0xFF193F38)),
                      style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9)),
                    ),
                    const SizedBox(height: 6),
                    IconButton(
                      tooltip: 'حذف المعلم',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.red),
                      style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF1F2)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isPending) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: Colors.red),
                      label: const Text('رفض المقترح',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.green),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('اعتماد ونشر',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImage(String? url) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? Image.network(url,
              key: ValueKey(url),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_rounded,
                  color: Color(0xFFCBD5E1)))
          : const Icon(Icons.image_rounded, color: Color(0xFFCBD5E1)),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = switch (status) {
      'منشور' => Colors.green,
      'قيد المراجعة' => const Color(0xFFD97706),
      'مرفوض' => Colors.red,
      _ => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}
