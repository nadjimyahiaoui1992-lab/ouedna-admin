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
      const Duration(minutes: 2),
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
        .subscribe();
  }

  void _queueReload() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 600), _reload);
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
      client.from('places').select('id,status'),
      client.from('testimonials').select('id,status'),
      client.from('memories').select('id'),
      client.from('feedback').select('id'),
    ]);

    stopwatch.stop();

    final places = (responses[0] as List);
    final testimonials = (responses[1] as List);
    final memoriesCount = (responses[2] as List).length;
    final feedbackCount = (responses[3] as List).length;

    return _AdminSnapshot(
      totalPlaces: places.length,
      publishedPlaces: places.where((item) => item['status'] == 'منشور').length,
      pendingPlaces:
          places.where((item) => item['status'] == 'قيد المراجعة').length,
      pendingTestimonials: testimonials
          .where((item) => item['status']?.toString() != 'approved')
          .length,
      memories: memoriesCount,
      feedback: feedbackCount,
      latency: stopwatch.elapsed,
      refreshedAt: DateTime.now(),
      accountEmail: client.auth.currentUser?.email ?? 'مدير النظام',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AdminSnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF193F38)));
        }
        if (snapshot.hasError) {
          return _ConnectionError(onRetry: _reload);
        }
        return _DashboardView(
          snapshot: snapshot.data!,
          onRefresh: _refresh,
          onOpenSection: widget.onOpenSection,
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

class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.snapshot,
    required this.onRefresh,
    required this.onOpenSection,
  });

  final _AdminSnapshot snapshot;
  final RefreshCallback onRefresh;
  final ValueChanged<int> onOpenSection;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF193F38),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          _buildStatusCard(context),
          const SizedBox(height: 28),
          _buildSectionTitle(context, 'المؤشرات الحية'),
          const SizedBox(height: 16),
          _buildMetricsGrid(context),
          const SizedBox(height: 28),
          _buildSectionTitle(context, 'إجراءات سريعة'),
          const SizedBox(height: 16),
          _buildQuickActions(context),
          const SizedBox(height: 32),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مرحباً بك،',
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'مركز القيادة',
                style: TextStyle(
                  color: const Color(0xFF193F38),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2EAE5)),
          ),
          child: const Icon(Icons.notifications_none_rounded,
              color: Color(0xFF193F38)),
        ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF193F38), Color(0xFF2A5C52)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF193F38).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.dns_rounded,
                    color: Color(0xFFD9A441), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'حالة الاتصال بالسحابة',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16),
                    ),
                    Text(
                      'Supabase Cloud • ${snapshot.latency.inMilliseconds}ms latency',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: Color(0xFF16A34A), size: 8),
                    SizedBox(width: 6),
                    Text('نشط',
                        style: TextStyle(
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.w900,
                            fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.alternate_email_rounded,
                  color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Text(snapshot.accountEmail,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: Color(0xFF193F38),
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _MetricCard(
          title: 'إجمالي المعالم',
          value: snapshot.totalPlaces.toString(),
          icon: Icons.map_rounded,
          color: const Color(0xFF193F38),
          trend: '${snapshot.publishedPlaces} منشور',
          onTap: () => onOpenSection(1),
        ),
        _MetricCard(
          title: 'طلبات المراجعة',
          value: snapshot.pendingPlaces.toString(),
          icon: Icons.pending_actions_rounded,
          color: const Color(0xFFD97706),
          trend: 'معالم جديدة',
          onTap: () => onOpenSection(1),
          isAlert: snapshot.pendingPlaces > 0,
        ),
        _MetricCard(
          title: 'تجارب الزوار',
          value: snapshot.pendingTestimonials.toString(),
          icon: Icons.reviews_rounded,
          color: const Color(0xFF2563EB),
          trend: 'بانتظار الموافقة',
          onTap: () => onOpenSection(2),
          isAlert: snapshot.pendingTestimonials > 0,
        ),
        _MetricCard(
          title: 'التفاعل العام',
          value: (snapshot.feedback + snapshot.memories).toString(),
          icon: Icons.auto_graph_rounded,
          color: const Color(0xFF7C3AED),
          trend: 'آراء وذكريات',
          onTap: () => onOpenSection(4),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          title: 'إدارة المحتوى السياحي',
          subtitle: 'تعديل المعالم، الصور، والإحداثيات',
          icon: Icons.edit_location_rounded,
          color: const Color(0xFF193F38),
          onTap: () => onOpenSection(1),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          title: 'مراجعة آراء المجتمع',
          subtitle: 'إدارة التعليقات والتجارب المنشورة',
          icon: Icons.people_alt_rounded,
          color: const Color(0xFFD9A441),
          onTap: () => onOpenSection(2),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        Text(
          'آخر تحديث: ${_formatTime(snapshot.refreshedAt)}',
          style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ouedna Admin • v1.2.0',
          style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 10,
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
    required this.onTap,
    this.isAlert = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;
  final VoidCallback onTap;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color:
                    isAlert ? color.withOpacity(0.3) : const Color(0xFFE2EAE5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 28),
                  if (isAlert)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900, color: color),
              ),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF193F38)),
              ),
              const SizedBox(height: 2),
              Text(
                trend,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2EAE5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: Color(0xFF193F38))),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionError extends StatelessWidget {
  const _ConnectionError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          const Text('تعذر الاتصال بقاعدة البيانات',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
