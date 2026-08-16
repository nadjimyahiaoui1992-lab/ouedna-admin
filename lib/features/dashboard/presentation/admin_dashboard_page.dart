import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tabs/announcement_composer_dialog.dart';
import 'tabs/memories_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/places_tab.dart';
import 'tabs/testimonials_tab.dart';
import 'tabs/update_management_dialog.dart';
import 'tabs/visitor_inbox_tab.dart';

const _ink = Color(0xFF173F36);
const _inkSoft = Color(0xFF2A5C50);
const _sand = Color(0xFFF7F3EC);
const _paper = Color(0xFFFFFEFC);
const _line = Color(0xFFE7E5DF);
const _muted = Color(0xFF78827D);
const _gold = Color(0xFFD39A3D);

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

enum _DashboardAction { announce, update, logout }

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _currentIndex = 0;

  late final List<Widget> _tabs = [
    OverviewTab(onOpenSection: _selectTab),
    const PlacesTab(),
    const TestimonialsTab(),
    const MemoriesTab(),
    const VisitorInboxTab(),
  ];

  void _selectTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    setState(() => _currentIndex = index);
  }

  Future<void> _handleAction(_DashboardAction action) async {
    switch (action) {
      case _DashboardAction.announce:
        if (!mounted) return;
        final message = await showDialog<String>(
          context: context,
          builder: (_) => const AnnouncementComposerDialog(),
        );
        if (message != null && mounted) _showMessage(message);
      case _DashboardAction.update:
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => const UpdateManagementDialog(),
        );
      case _DashboardAction.logout:
        await Supabase.instance.client.auth.signOut();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return Scaffold(
            backgroundColor: _sand,
            body: isWide
                ? Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      Expanded(child: _buildMainContent()),
                      _buildSidebar(),
                    ],
                  )
                : _buildMainContent(),
            bottomNavigationBar: isWide ? null : _buildMobileNavigation(),
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(child: IndexedStack(index: _currentIndex, children: _tabs)),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _paper,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sectionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'مركز إدارة منصة وادنا السياحية',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _TopActionButton(
                tooltip: 'نشر إشعار للزوار',
                icon: Icons.campaign_outlined,
                color: _gold,
                backgroundColor: const Color(0xFFFFF3D9),
                onPressed: () => _handleAction(_DashboardAction.announce),
              ),
              const SizedBox(width: 6),
              _TopActionButton(
                tooltip: 'إدارة تحديث التطبيق',
                icon: Icons.system_update_alt_outlined,
                color: _ink,
                backgroundColor: const Color(0xFFEAF3EF),
                onPressed: () => _handleAction(_DashboardAction.update),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<_DashboardAction>(
                tooltip: 'حساب المدير',
                onSelected: _handleAction,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _DashboardAction.logout,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout_rounded, color: Colors.red),
                      title: Text('تسجيل الخروج'),
                    ),
                  ),
                ],
                child: const CircleAvatar(
                  radius: 20,
                  backgroundColor: _ink,
                  child: Icon(Icons.person_outline_rounded,
                      color: Colors.white, size: 21),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _sectionTitle => switch (_currentIndex) {
        0 => 'مركز القيادة',
        1 => 'إدارة المعالم',
        2 => 'تجارب الزوار',
        3 => 'الذاكرة والتراث',
        4 => 'صندوق الوارد',
        _ => 'لوحة الإدارة',
      };

  Widget _buildSidebar() {
    return Container(
      width: 270,
      decoration: const BoxDecoration(
        color: _paper,
        border: Border(left: BorderSide(color: _line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBrand(),
              const SizedBox(height: 30),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'مساحة العمل',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _SidebarItem(
                      label: 'الرئيسية',
                      caption: 'نظرة عامة وإحصائيات',
                      icon: Icons.grid_view_rounded,
                      selected: _currentIndex == 0,
                      onTap: () => _selectTab(0),
                    ),
                    _SidebarItem(
                      label: 'المعالم',
                      caption: 'المحتوى والمواقع والصور',
                      icon: Icons.location_on_outlined,
                      selected: _currentIndex == 1,
                      onTap: () => _selectTab(1),
                    ),
                    _SidebarItem(
                      label: 'التجارب',
                      caption: 'مراجعة شهادات الزوار',
                      icon: Icons.auto_awesome_outlined,
                      selected: _currentIndex == 2,
                      onTap: () => _selectTab(2),
                    ),
                    _SidebarItem(
                      label: 'الذاكرة',
                      caption: 'الأرشيف والتراث المحلي',
                      icon: Icons.auto_stories_outlined,
                      selected: _currentIndex == 3,
                      onTap: () => _selectTab(3),
                    ),
                    _SidebarItem(
                      label: 'صوت الزوار',
                      caption: 'الرسائل والاقتراحات',
                      icon: Icons.forum_outlined,
                      selected: _currentIndex == 4,
                      onTap: () => _selectTab(4),
                    ),
                  ],
                ),
              ),
              _buildConnectionCard(),
              const SizedBox(height: 12),
              _buildAccountCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: _ink.withOpacity(.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.explore_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ouedna',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
            ),
            Text(
              'وادنا · الإدارة المركزية',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCEBE3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_done_outlined, color: Color(0xFF16805B), size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('البيانات متصلة',
                    style: TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w900)),
                Text('Supabase Cloud',
                    style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Icon(Icons.circle, color: Color(0xFF22A06B), size: 8),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    final email =
        Supabase.instance.client.auth.currentUser?.email ?? 'مدير النظام';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _sand,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: _inkSoft,
            child: Icon(Icons.person_outline_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _ink, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'تسجيل الخروج',
            onPressed: () => _handleAction(_DashboardAction.logout),
            icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNavigation() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _selectTab,
      height: 72,
      backgroundColor: _paper,
      indicatorColor: const Color(0x22214A3B),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded, color: _ink),
          label: 'الرئيسية',
        ),
        NavigationDestination(
          icon: Icon(Icons.location_on_outlined),
          selectedIcon: Icon(Icons.location_on_rounded, color: _ink),
          label: 'المعالم',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          selectedIcon: Icon(Icons.auto_awesome_rounded, color: _ink),
          label: 'التجارب',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_stories_outlined),
          selectedIcon: Icon(Icons.auto_stories_rounded, color: _ink),
          label: 'الذاكرة',
        ),
        NavigationDestination(
          icon: Icon(Icons.forum_outlined),
          selectedIcon: Icon(Icons.forum_rounded, color: _ink),
          label: 'الوارد',
        ),
      ],
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.caption,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String caption;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEAF3EF) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? const Color(0xFFD1E5DB) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: selected ? _ink : _muted, size: 21),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: selected ? _ink : const Color(0xFF46554F),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.chevron_left_rounded, color: _ink, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
