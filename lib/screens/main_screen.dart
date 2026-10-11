import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

import '../constants/app_colors.dart';
import 'todo_page.dart';
import 'cycle_page.dart';
import 'settings_page.dart';
import 'journal_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  final PageController _pageController = PageController();
  static const _modules = ['todo', 'journal', 'calendar', 'settings'];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;

    _restoreModule();
  }

  Future<void> _restoreModule() async {
    final provider = context.read<AppProvider>();
    await provider.ready;
    if (!mounted) return;
    setState(() {
      _currentIndex = _modules.indexOf(provider.lastModule);
      _loaded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
    context.read<AppProvider>().setLastModule(_modules[index]);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: SizedBox.expand());
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          TodoPage(),
          JournalPage(),
          CyclePage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textGrey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
        elevation: 2,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            activeIcon: Icon(Icons.check_circle),
            label: '待办',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_note_outlined),
            label: '记录',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            label: '时历',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
