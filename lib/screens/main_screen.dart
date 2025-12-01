import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import 'timer_page.dart';
import 'todo_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = const [TimerPage(), TodoPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 16,
              24,
              16,
            ),
            color: AppColors.bg,
            child: Row(
              children: [
                Text(
                  "寸光",
                  style: GoogleFonts.zhiMangXing(
                    fontSize: 36,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textDark,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_done_outlined,
                        size: 14,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "已同步",
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _pages[_currentIndex]),
          Container(
            width: double.infinity,
            color: AppColors.bg,
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              "All rights reserved: Symplatt",
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansSc(
                fontSize: 10,
                color: Colors.grey[400],
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          currentIndex: _currentIndex,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          onTap: (idx) => setState(() => _currentIndex = idx),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.hourglass_empty_rounded),
              activeIcon: Icon(Icons.hourglass_full_rounded),
              label: '专注',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.format_list_bulleted_rounded),
              activeIcon: Icon(Icons.checklist_rtl_rounded),
              label: '清单',
            ),
          ],
        ),
      ),
    );
  }
}
