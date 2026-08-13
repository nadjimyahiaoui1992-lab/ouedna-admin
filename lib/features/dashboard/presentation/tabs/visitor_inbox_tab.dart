import 'package:flutter/material.dart';

import 'feedback_tab.dart';
import 'suggestions_tab.dart';

class VisitorInboxTab extends StatelessWidget {
  const VisitorInboxTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Color(0xFF193F38),
              indicatorColor: Color(0xFF193F38),
              tabs: [
                Tab(
                  icon: Icon(Icons.star_rate_rounded),
                  text: 'التقييمات',
                ),
                Tab(
                  icon: Icon(Icons.mark_unread_chat_alt_rounded),
                  text: 'الرسائل',
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                FeedbackTab(),
                SuggestionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
