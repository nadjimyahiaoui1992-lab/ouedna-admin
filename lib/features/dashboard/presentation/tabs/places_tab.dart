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

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  void _loadPlaces() {
    _placesFuture = Supabase.instance.client
        .from('places')
        .select()
        .order('created_at', ascending: false);
  }

  Future<void> _deletePlace(String id) async {
    try {
      await Supabase.instance.client.from('places').delete().eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المعلم بنجاح')),
      );
      setState(() {
        _loadPlaces();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء الحذف: $e')),
      );
    }
  }

  void _openPlaceForm([Map<String, dynamic>? place]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PlaceFormDialog(place: place),
    );
    if (result == true && mounted) {
      setState(() {
        _loadPlaces();
      });
    }
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
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          final places = snapshot.data ?? [];
          if (places.isEmpty) {
            return const Center(child: Text('لا توجد معالم مضافة بعد'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: place['image_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            place['image_url'],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image),
                          ),
                        )
                      : const Icon(Icons.image_not_supported, size: 40),
                  title: Text(place['name'] ?? 'بدون اسم',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${place['category'] ?? ''} • ${place['status'] ?? 'منشور'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                        onPressed: () => _openPlaceForm(place),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, color: Colors.red),
                        onPressed: () => _deletePlace(place['id'].toString()),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF193F38),
        foregroundColor: Colors.white,
        onPressed: () => _openPlaceForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة معلم جديد'),
      ),
    );
  }
}
