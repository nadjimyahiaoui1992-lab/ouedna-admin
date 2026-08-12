import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tabs/feedback_tab.dart';
import 'tabs/memories_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/places_tab.dart';
import 'tabs/testimonials_tab.dart';

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
    const FeedbackTab(),
  ];

  static const _sectionTitles = [
    'مركز القيادة',
    'إدارة المعالم',
    'تجارب الزوار',
    'الذاكرة والتراث',
    'آراء الزوار',
  ];

  void _selectTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = Supabase.instance.client.auth.currentUser?.email;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          titleSpacing: 18,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Souf 360 Admin',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                _sectionTitles[_currentIndex],
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            if (userEmail != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 2),
                child: Tooltip(
                  message: userEmail,
                  child: const Icon(Icons.verified_user_outlined, size: 21),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'تسجيل الخروج',
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
              },
            ),
          ],
        ),
        body: IndexedStack(index: _currentIndex, children: _tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectTab,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.place_outlined),
              selectedIcon: Icon(Icons.place_rounded),
              label: 'المعالم',
            ),
            NavigationDestination(
              icon: Icon(Icons.rate_review_outlined),
              selectedIcon: Icon(Icons.rate_review_rounded),
              label: 'التجارب',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_edu_outlined),
              selectedIcon: Icon(Icons.history_edu_rounded),
              label: 'الذكريات',
            ),
            NavigationDestination(
              icon: Icon(Icons.feedback_outlined),
              selectedIcon: Icon(Icons.feedback_rounded),
              label: 'الآراء',
            ),
          ],
        ),
      ),
    );
  }
}
