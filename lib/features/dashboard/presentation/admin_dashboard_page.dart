import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tabs/announcement_composer_dialog.dart';
import 'tabs/memories_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/places_tab.dart';
import 'tabs/testimonials_tab.dart';
import 'tabs/update_management_dialog.dart';
import 'tabs/visitor_inbox_tab.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF7EA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFCF7),
          foregroundColor: const Color(0xFF214A3B),
          elevation: 0,
          toolbarHeight: 75,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF214A3B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded,
                    color: Color(0xFF214A3B)),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ouedna · وادنا',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.5),
                  ),
                  Text(
                    'نظام الإدارة المركزي',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF756452)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'نشر إشعار للزوار',
              onPressed: () async {
                final message = await showDialog<String>(
                  context: context,
                  builder: (_) => const AnnouncementComposerDialog(),
                );
                if (message != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9C5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: Color(0xFFB85E32), size: 20),
              ),
            ),
            IconButton(
              tooltip: 'إدارة تحديث التطبيق',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const UpdateManagementDialog(),
              ),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6F3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.system_update_alt_rounded,
                    color: Color(0xFF214A3B), size: 20),
              ),
            ),
            IconButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Color(0xFFDC2626), size: 20),
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: const Color(0xFFE5D2B4), height: 1),
          ),
        ),
        body: IndexedStack(index: _currentIndex, children: _tabs),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5)),
            ],
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _selectTab,
            backgroundColor: const Color(0xFFFFFCF7),
            indicatorColor: const Color(0xFF214A3B).withOpacity(0.10),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 70,
            destinations: [
              _buildNavDestination(Icons.dashboard_outlined,
                  Icons.dashboard_rounded, 'الرئيسية'),
              _buildNavDestination(
                  Icons.map_outlined, Icons.map_rounded, 'المعالم'),
              _buildNavDestination(
                  Icons.reviews_outlined, Icons.reviews_rounded, 'التجارب'),
              _buildNavDestination(Icons.auto_stories_outlined,
                  Icons.auto_stories_rounded, 'الذكريات'),
              _buildNavDestination(
                  Icons.forum_outlined, Icons.forum_rounded, 'صوت الزوار'),
            ],
          ),
        ),
      ),
    );
  }

  NavigationDestination _buildNavDestination(
      IconData icon, IconData selectedIcon, String label) {
    return NavigationDestination(
      icon: Icon(icon, color: const Color(0xFF756452)),
      selectedIcon: Icon(selectedIcon, color: const Color(0xFF214A3B)),
      label: label,
    );
  }
}
