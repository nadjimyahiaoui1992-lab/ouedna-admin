import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key, required this.onOpenSection});

  final ValueChanged<int> onOpenSection;

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  late Future<_AdminSnapshot> _snapshotFuture;
  RealtimeChannel? _channel;
  Timer? _refreshDebounce;
  Timer? _periodicRefresh;

  @override
  void initState() {
    super.initState();
    _reload();
    _subscribeToChanges();
    _periodicRefresh = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _reload(),
    );
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _periodicRefresh?.cancel();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  void _subscribeToChanges() {
    final client = Supabase.instance.client;
    _channel = client
        .channel('souf-admin-dashboard-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'places',
          callback: (_) => _queueReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'testimonials',
          callback: (_) => _queueReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'memories',
          callback: (_) => _queueReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'feedback',
          callback: (_) => _queueReload(),
        )
        .subscribe();
  }

  void _queueReload() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 450), _reload);
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  Future<void> _refresh() async {
    _reload();
    await _snapshotFuture;
  }

  Future<_AdminSnapshot> _loadSnapshot() async {
    final client = Supabase.instance.client;
    final stopwatch = Stopwatch()..start();
    final responses = await Future.wait([
      client
          .from('places')
          .select('id,status,updated_at,created_at')
          .limit(1000),
      client.from('testimonials').select('id,status,created_at').limit(1000),
      client.from('memories').select('id,created_at').limit(1000),
      client.from('feedback').select('id,created_at').limit(1000),
    ]);
    stopwatch.stop();

    final places = _maps(responses[0]);
    final testimonials = _maps(responses[1]);
    final memories = _maps(responses[2]);
    final feedback = _maps(responses[3]);

    return _AdminSnapshot(
      totalPlaces: places.length,
      publishedPlaces: places.where((item) => item['status'] == 'منشور').length,
      pendingPlaces:
          places.where((item) => item['status'] == 'قيد المراجعة').length,
      pendingTestimonials: testimonials
          .where((item) => item['status']?.toString() != 'approved')
          .length,
      memories: memories.length,
      feedback: feedback.length,
      latency: stopwatch.elapsed,
      refreshedAt: DateTime.now(),
      accountEmail: client.auth.currentUser?.email ?? 'مشرف Souf 360',
    );
  }

  List<Map<String, dynamic>> _maps(dynamic response) =>
      (response as List<dynamic>).whereType<Map<String, dynamic>>().toList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AdminSnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ConnectionError(onRetry: _reload, error: snapshot.error);
        }
        return _CommandCenter(
          snapshot: snapshot.data!,
          onRefresh: _refresh,
          onOpenPlaces: () => widget.onOpenSection(1),
          onOpenTestimonials: () => widget.onOpenSection(2),
          onOpenMemories: () => widget.onOpenSection(3),
          onOpenFeedback: () => widget.onOpenSection(4),
        );
      },
    );
  }
}

class _AdminSnapshot {
  const _AdminSnapshot({
    required this.totalPlaces,
    required this.publishedPlaces,
    required this.pendingPlaces,
    required this.pendingTestimonials,
    required this.memories,
    required this.feedback,
    required this.latency,
    required this.refreshedAt,
    required this.accountEmail,
  });

  final int totalPlaces;
  final int publishedPlaces;
  final int pendingPlaces;
  final int pendingTestimonials;
  final int memories;
  final int feedback;
  final Duration latency;
  final DateTime refreshedAt;
  final String accountEmail;
}

class _CommandCenter extends StatelessWidget {
  const _CommandCenter({
    required this.snapshot,
    required this.onRefresh,
    required this.onOpenPlaces,
    required this.onOpenTestimonials,
    required this.onOpenMemories,
    required this.onOpenFeedback,
  });

  final _AdminSnapshot snapshot;
  final RefreshCallback onRefresh;
  final VoidCallback onOpenPlaces;
  final VoidCallback onOpenTestimonials;
  final VoidCallback onOpenMemories;
  final VoidCallback onOpenFeedback;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 106),
        children: [
          _ConnectionHero(snapshot: snapshot),
          const SizedBox(height: 18),
          Text(
            'نظرة تشغيلية',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 154,
            ),
            children: [
              _MetricCard(
                label: 'إجمالي المعالم',
                value: snapshot.totalPlaces.toString(),
                note: '${snapshot.publishedPlaces} منشور للعامة',
                icon: Icons.place_rounded,
                color: const Color(0xFF193F38),
                onTap: onOpenPlaces,
              ),
              _MetricCard(
                label: 'بانتظار المراجعة',
                value: snapshot.pendingPlaces.toString(),
                note: 'اقتراحات معالم الزوار',
                icon: Icons.fact_check_rounded,
                color: const Color(0xFFD88718),
                onTap: onOpenPlaces,
              ),
              _MetricCard(
                label: 'تجارب تحتاج مراجعة',
                value: snapshot.pendingTestimonials.toString(),
                note: 'آراء وصور المجتمع',
                icon: Icons.rate_review_rounded,
                color: const Color(0xFF4863A0),
                onTap: onOpenTestimonials,
              ),
              _MetricCard(
                label: 'آراء وذكريات',
                value: '${snapshot.feedback + snapshot.memories}',
                note: '${snapshot.feedback} رأياً • ${snapshot.memories} ذاكرة',
                icon: Icons.forum_rounded,
                color: const Color(0xFF8A5C4A),
                onTap: onOpenFeedback,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'مركز المراجعة',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _ReviewQueueCard(
            icon: Icons.add_location_alt_rounded,
            title: 'اقتراحات المعالم',
            subtitle: snapshot.pendingPlaces == 0
                ? 'لا توجد اقتراحات معلقة حالياً.'
                : '${snapshot.pendingPlaces} اقتراحاً بانتظار الاعتماد والنشر.',
            buttonLabel:
                snapshot.pendingPlaces == 0 ? 'إدارة المعالم' : 'مراجعة الآن',
            color: const Color(0xFFD9A441),
            onTap: onOpenPlaces,
          ),
          const SizedBox(height: 12),
          _ReviewQueueCard(
            icon: Icons.photo_camera_back_rounded,
            title: 'تجارب الزوار',
            subtitle: snapshot.pendingTestimonials == 0
                ? 'جميع التجارب المنشورة محدثة.'
                : '${snapshot.pendingTestimonials} تجربة بانتظار الاعتماد.',
            buttonLabel: snapshot.pendingTestimonials == 0
                ? 'فتح التجارب'
                : 'مراجعة الآن',
            color: const Color(0xFF4863A0),
            onTap: onOpenTestimonials,
          ),
          const SizedBox(height: 22),
          Text(
            'إدارة المحتوى',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _ManagementGrid(
            onOpenPlaces: onOpenPlaces,
            onOpenMemories: onOpenMemories,
            onOpenFeedback: onOpenFeedback,
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'اسحب للتحديث • آخر مزامنة: ${_formatTime(snapshot.refreshedAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ConnectionHero extends StatelessWidget {
  const _ConnectionHero({required this.snapshot});

  final _AdminSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF193F38), Color(0xFF0F5C50)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33193F38),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.hub_rounded, color: Color(0xFFD9A441)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'قاعدة بيانات Souf 360',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Supabase • مزامنة مركزية مباشرة',
                      style: TextStyle(color: Color(0xFFDDEBE7), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const _LiveStatusPill(),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.speed_rounded,
                    color: Color(0xFFD9A441), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم الاتصال بنجاح • استجابة قاعدة البيانات ${snapshot.latency.inMilliseconds} ms',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            snapshot.accountEmail,
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: Color(0xFFDDEBE7), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _LiveStatusPill extends StatelessWidget {
  const _LiveStatusPill();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: Color(0xFF16A34A)),
            SizedBox(width: 5),
            Text(
              'متصل',
              style: TextStyle(
                color: Color(0xFF166534),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: color.withOpacity(.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_back_ios_new_rounded,
                        size: 13, color: color),
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 25,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ReviewQueueCard extends StatelessWidget {
  const _ReviewQueueCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onTap, child: Text(buttonLabel)),
            ],
          ),
        ),
      );
}

class _ManagementGrid extends StatelessWidget {
  const _ManagementGrid({
    required this.onOpenPlaces,
    required this.onOpenMemories,
    required this.onOpenFeedback,
  });

  final VoidCallback onOpenPlaces;
  final VoidCallback onOpenMemories;
  final VoidCallback onOpenFeedback;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _ManagementButton(
              icon: Icons.edit_location_alt_rounded,
              label: 'المعالم',
              color: const Color(0xFF193F38),
              onTap: onOpenPlaces,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ManagementButton(
              icon: Icons.auto_stories_rounded,
              label: 'الذكريات',
              color: const Color(0xFF8A5C4A),
              onTap: onOpenMemories,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ManagementButton(
              icon: Icons.feedback_rounded,
              label: 'الآراء',
              color: const Color(0xFF4863A0),
              onTap: onOpenFeedback,
            ),
          ),
        ],
      );
}

class _ManagementButton extends StatelessWidget {
  const _ManagementButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ConnectionError extends StatelessWidget {
  const _ConnectionError({required this.onRetry, required this.error});

  final VoidCallback onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0x1FDC2626),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 42,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'تعذر الاتصال بقاعدة بيانات Souf 360',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'تحقق من الإنترنت وصلاحيات الحساب ثم أعد المحاولة.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة الاتصال'),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  'رمز التشخيص: ${error.runtimeType}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                ),
              ],
            ],
          ),
        ),
      );
}
