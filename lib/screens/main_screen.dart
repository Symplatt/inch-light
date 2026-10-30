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
  double _headerDrag = double.nan;
  Offset _headerStart = Offset.zero;

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
    final provider = context.read<AppProvider>();
    provider.setLastModule(_modules[index]);
    if (index == 2) provider.markCalendarAlertsSeen();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: SizedBox.expand());
    final provider = context.watch<AppProvider>();
    return Scaffold(
      body: Listener(
        onPointerDown: (event) {
          final top = MediaQuery.paddingOf(context).top;
          _headerDrag =
              event.localPosition.dy >= top &&
                  event.localPosition.dy <= top + kToolbarHeight
              ? event.pointer.toDouble()
              : double.nan;
          _headerStart = event.localPosition;
        },
        onPointerCancel: (_) => _headerDrag = double.nan,
        onPointerUp: (event) {
          if (_headerDrag != event.pointer.toDouble()) return;
          final delta = event.localPosition - _headerStart;
          if (delta.dx.abs() < 48 || delta.dy.abs() > 24) return;
          final next = _currentIndex + (delta.dx < 0 ? 1 : -1);
          if (next >= 0 && next < _modules.length) _onTabTapped(next);
        },
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            TodoPage(),
            JournalPage(),
            CyclePage(),
            SettingsPage(),
          ],
        ),
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
        items: [
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
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.calendar_month_outlined),
                if (provider.hasCalendarAlerts)
                  Positioned(
                    right: provider.hasNewCalendarAlerts ? -10 : -3,
                    top: -4,
                    child: provider.hasNewCalendarAlerts
                        ? Container(
                            key: const ValueKey('calendar-new'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'new',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                height: 1,
                              ),
                            ),
                          )
                        : Container(
                            key: const ValueKey('calendar-dot'),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
              ],
            ),
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
