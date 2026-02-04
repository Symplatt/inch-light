import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../constants/app_colors.dart';
import '../models/task_model.dart';
import 'timer_page.dart';
import 'todo_page.dart';
import 'cycle_page.dart';

// 全局通用的设置弹窗
void showGlobalSettingsDialog(BuildContext context, AppProvider provider) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Center(child: Text("数据设置")),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file, color: AppColors.primary),
            title: const Text("导出数据"),
            subtitle: const Text("复制全部数据到剪贴板"),
            onTap: () {
              final json = provider.exportData();
              Clipboard.setData(ClipboardData(text: json));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("数据已复制")));
              Navigator.pop(ctx);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download, color: AppColors.danger),
            title: const Text("导入数据"),
            subtitle: const Text("警告：将覆盖当前所有数据"),
            onTap: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) {
                if (ctx.mounted) {
                  showDialog(
                    context: ctx,
                    builder: (subCtx) => AlertDialog(
                      title: const Text("确认覆盖？"),
                      content: const Text("此操作不可撤销，当前所有数据将被删除。"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(subCtx),
                          child: const Text("取消"),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(subCtx);
                            bool success = await provider.importData(
                              data!.text!,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? "导入成功" : "数据格式错误"),
                                ),
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text(
                            "确认导入",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              } else {
                if (context.mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("剪贴板为空")));
              }
            },
          ),
        ],
      ),
    ),
  );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _currentIndex = provider.lastPageIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
    Provider.of<AppProvider>(context, listen: false).setLastPageIndex(index);
  }

  String _formatDuration(int sec) {
    Duration d = Duration(seconds: sec);
    return "${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        if (provider.isFocusMode) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }

        TaskItem? activeTask;
        if (provider.activeTimerId != null) {
          try {
            activeTask = provider.timerTasks.firstWhere(
              (t) => t.id == provider.activeTimerId,
            );
          } catch (_) {}
        }

        return Stack(
          children: [
            Scaffold(
              body: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: const [TimerPage(), TodoPage(), CyclePage()],
              ),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: _onTabTapped,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.white,
                  selectedItemColor: AppColors.primary,
                  unselectedItemColor: AppColors.textGrey,
                  showUnselectedLabels: true,
                  elevation: 0,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.timer_outlined),
                      activeIcon: Icon(Icons.timer),
                      label: '专注',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.check_circle_outline),
                      activeIcon: Icon(Icons.check_circle),
                      label: '待办',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.loop),
                      activeIcon: Icon(Icons.loop),
                      label: '周期',
                    ),
                  ],
                ),
              ),
            ),

            // 专注增强模式
            if (provider.isFocusMode && activeTask != null)
              Positioned.fill(
                child: Material(
                  color: Colors.black,
                  child: GestureDetector(
                    onTap: () => provider.exitFocusMode(),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            activeTask.title,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 24,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            _formatDuration(activeTask.durationSeconds),
                            style: TextStyle(
                              color:
                                  taskColors[activeTask.colorIndex %
                                      taskColors.length],
                              // 【修改点】字体改小到 64
                              fontSize: 64,
                              fontFamily: 'Monospace',
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 60),
                          const Text(
                            "点击屏幕唤醒",
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 16,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
