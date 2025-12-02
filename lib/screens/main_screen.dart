import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import 'timer_page.dart';
import 'todo_page.dart';
import 'cycle_page.dart'; // 确保你创建了 cycle_page.dart 文件

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 页面列表：专注、清单、周期
  final List<Widget> _pages = const [TimerPage(), TodoPage(), CyclePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用 Column 布局来实现顶部、中间内容、底部版权的垂直排列
      body: Column(
        children: [
          // ==================== 顶部自定义导航栏 ====================
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 16, // 适配刘海屏高度
              24,
              16,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary, // 紫色背景
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 艺术字标题
                Text(
                  "寸光",
                  style: const TextStyle(
                    fontFamily: 'ArtFont', // 这里填你在 yaml 里定义的 family 名字
                    fontSize: 36,
                    fontWeight: FontWeight.w400, // 或者是 w500, 看字体粗细效果
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                // 右侧状态标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2), // 半透明白色背景
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.cloud_done_rounded,
                        size: 14,
                        color: Colors.white, // 白色图标
                      ),
                      SizedBox(width: 4),
                      Text(
                        "已同步",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white, // 白色文字
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ==================== 中间内容区域 ====================
          Expanded(child: _pages[_currentIndex]),

          // ==================== 底部版权文字 ====================
          Container(
            width: double.infinity,
            color: AppColors.bg, // 与页面背景一致
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              "All rights reserved: Symplatt",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[400],
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),

      // ==================== 底部导航栏 ====================
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
            // 新增的周期模块入口
            BottomNavigationBarItem(
              icon: Icon(Icons.update),
              activeIcon: Icon(Icons.history_toggle_off),
              label: '周期',
            ),
          ],
        ),
      ),
    );
  }
}
