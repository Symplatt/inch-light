import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/task_model.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';
import 'main_screen.dart'; // 引入以使用 _showGlobalSettingsDialog

class TimerPage extends StatelessWidget {
  const TimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // 获取当前正在计时的任务（用于黑屏显示）
    TaskItem? activeTask;
    if (provider.activeTimerId != null) {
      try {
        activeTask = provider.timerTasks.firstWhere(
          (t) => t.id == provider.activeTimerId,
        );
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          '专注任务',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          // 需求2：Settings 按钮
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textDark,
            ),
            onPressed: () => showGlobalSettingsDialog(context, provider),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 正常列表层
          Column(
            children: [
              Expanded(
                child: provider.timerTasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_off_outlined,
                              size: 60,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "点击右下角添加专注任务",
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                        children: [
                          ...provider.timerTasks.map(
                            (task) => _buildTimerCard(context, task, provider),
                          ),
                        ],
                      ),
              ),
            ],
          ),

          // 需求5：专注增强模式（黑屏遮罩）
          if (provider.isFocusMode && activeTask != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => provider.exitFocusMode(), // 点击退出黑屏
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        activeTask.title,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _formatDuration(activeTask.durationSeconds),
                        style: TextStyle(
                          color:
                              taskColors[activeTask.colorIndex %
                                  taskColors.length],
                          fontSize: 80,
                          fontFamily: 'Monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        "点击屏幕唤醒",
                        style: TextStyle(color: Colors.white24, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "timer_add",
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTimerCard(
    BuildContext context,
    TaskItem task,
    AppProvider provider,
  ) {
    bool isRunning = provider.activeTimerId == task.id;
    Color themeColor =
        (task.colorIndex >= 0 && task.colorIndex < taskColors.length)
        ? taskColors[task.colorIndex]
        : taskColors[0];
    String timeStr = _formatDuration(task.durationSeconds);

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => provider.deleteTimerTask(task),
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.shadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              if (isRunning)
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => provider.toggleTimer(task),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isRunning ? themeColor : AppColors.bg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isRunning ? Icons.pause : Icons.play_arrow_rounded,
                          color: isRunning ? Colors.white : AppColors.textDark,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task.timerMode == TimerMode.countdown
                                  ? "倒计时"
                                  : "正计时",
                              style: TextStyle(
                                fontSize: 10,
                                color: themeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 24,
                            fontFamily: 'Monospace',
                            fontWeight: FontWeight.bold,
                            color: isRunning ? themeColor : Colors.grey[300],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showOptions(context, provider, task),
                          child: Icon(
                            Icons.more_horiz,
                            color: Colors.grey[400],
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, AppProvider provider, TaskItem task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Center(
          child: Text(
            task.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Center(child: Text("重命名")),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, provider, task);
              },
            ),
            const Divider(height: 1),
            ListTile(
              title: const Center(child: Text("重置时间")),
              onTap: () {
                provider.resetTimerTask(task);
                Navigator.pop(ctx);
              },
            ),
            const Divider(height: 1),
            ListTile(
              title: const Center(
                child: Text("删除任务", style: TextStyle(color: Colors.red)),
              ),
              onTap: () {
                provider.deleteTimerTask(task);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    TextEditingController tc = TextEditingController();
    TimerMode mode = TimerMode.stopwatch;
    int h = 0, m = 0, s = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "开启新专注",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: tc,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "给任务起个名字...",
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ModeChipWidget(
                    label: "正计时",
                    selected: mode == TimerMode.stopwatch,
                    onTap: () => setState(() => mode = TimerMode.stopwatch),
                  ),
                  const SizedBox(width: 12),
                  ModeChipWidget(
                    label: "倒计时",
                    selected: mode == TimerMode.countdown,
                    onTap: () => setState(() => mode = TimerMode.countdown),
                  ),
                ],
              ),
              if (mode == TimerMode.countdown) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TimeInputWidget(
                        label: "时",
                        onChanged: (v) => h = int.tryParse(v) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TimeInputWidget(
                        label: "分",
                        onChanged: (v) => m = int.tryParse(v) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TimeInputWidget(
                        label: "秒",
                        onChanged: (v) => s = int.tryParse(v) ?? 0,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textDark,
                    // 需求1：按钮文字高亮
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    if (tc.text.trim().isEmpty) return;
                    int? target = (mode == TimerMode.countdown)
                        ? (h * 3600 + m * 60 + s)
                        : null;
                    if (mode == TimerMode.countdown &&
                        (target == null || target == 0))
                      return;
                    Provider.of<AppProvider>(
                      context,
                      listen: false,
                    ).addTimerTask(tc.text, mode: mode, targetSeconds: target);
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    "开始行动",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    AppProvider provider,
    TaskItem task,
  ) {
    TextEditingController tc = TextEditingController(text: task.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("重命名"),
        content: TextField(
          controller: tc,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              if (tc.text.isNotEmpty) {
                provider.renameTimerTask(task, tc.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text("确定"),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int sec) {
    Duration d = Duration(seconds: sec);
    return "${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }
}
