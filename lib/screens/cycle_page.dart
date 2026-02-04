import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/app_provider.dart';
import '../models/task_model.dart';
import '../constants/app_colors.dart';
import 'main_screen.dart';

class CyclePage extends StatelessWidget {
  const CyclePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final tasks = provider.cycleTasks;
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        final dayAfterStart = todayStart.add(const Duration(days: 2));

        final todayTasks = tasks
            .where((t) => t.nextRunTime.isBefore(tomorrowStart))
            .toList();
        final tomorrowTasks = tasks
            .where(
              (t) =>
                  t.nextRunTime.isAfter(
                    tomorrowStart.subtract(const Duration(seconds: 1)),
                  ) &&
                  t.nextRunTime.isBefore(dayAfterStart),
            )
            .toList();
        final futureTasks = tasks
            .where(
              (t) => t.nextRunTime.isAfter(
                dayAfterStart.subtract(const Duration(seconds: 1)),
              ),
            )
            .toList();

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            centerTitle: false,
            title: const Text(
              '周期提醒',
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppColors.textDark,
                ),
                onPressed: () => showGlobalSettingsDialog(context, provider),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              _buildSectionHeader("今天"),
              if (todayTasks.isEmpty) _buildEmptyState(),
              ...todayTasks.map((t) => _buildCycleCard(context, t, provider)),

              _buildSectionHeader("明天"),
              if (tomorrowTasks.isEmpty) _buildEmptyState(),
              ...tomorrowTasks.map(
                (t) => _buildCycleCard(context, t, provider),
              ),

              _buildSectionHeader("未来"),
              if (futureTasks.isEmpty) _buildEmptyState(),
              ...futureTasks.map((t) => _buildCycleCard(context, t, provider)),

              const SizedBox(height: 80),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.primary,
            onPressed: () => _showAddCycleDialog(context),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerLeft,
      child: const Text("无任务", style: TextStyle(color: AppColors.textGrey)),
    );
  }

  Widget _buildCycleCard(
    BuildContext context,
    CycleTask task,
    AppProvider provider,
  ) {
    // 【修改点】获取周期对应的颜色
    Color tagColor;
    String tagText;
    switch (task.frequency) {
      case CycleFrequency.daily:
        tagColor = Colors.blueAccent;
        tagText = "每天";
        break;
      case CycleFrequency.weekly:
        tagColor = Colors.purpleAccent;
        tagText = "每周";
        break;
      case CycleFrequency.monthly:
        tagColor = Colors.orangeAccent;
        tagText = "每月";
        break;
      case CycleFrequency.yearly:
        tagColor = Colors.redAccent;
        tagText = "每年";
        break;
    }

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => provider.removeCycleTask(task),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.shadow,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tagColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.loop, color: tagColor, size: 22),
          ),
          title: Text(
            task.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Row(
              children: [
                // 【修改点】彩色胶囊标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tagText,
                    style: TextStyle(
                      fontSize: 10,
                      color: tagColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "下次: ${DateFormat('MM-dd HH:mm').format(task.nextRunTime)}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCycleDialog(BuildContext context) {
    final titleController = TextEditingController();
    CycleFrequency frequency = CycleFrequency.daily;
    DateTime selectedTime = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "新建周期任务",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: "任务名称"),
                ),
                const SizedBox(height: 10),
                DropdownButton<CycleFrequency>(
                  value: frequency,
                  isExpanded: true,
                  items: CycleFrequency.values.map((e) {
                    String label = "";
                    switch (e) {
                      case CycleFrequency.daily:
                        label = "每天";
                        break;
                      case CycleFrequency.weekly:
                        label = "每周 (按设定日)";
                        break;
                      case CycleFrequency.monthly:
                        label = "每月 (按设定日)";
                        break;
                      case CycleFrequency.yearly:
                        label = "每年 (按设定日)";
                        break;
                    }
                    return DropdownMenuItem(value: e, child: Text(label));
                  }).toList(),
                  onChanged: (val) => setState(() => frequency = val!),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "首次运行: ${DateFormat('yyyy-MM-dd HH:mm').format(selectedTime)}",
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final now = DateTime.now();
                    DateTime tempDate = selectedTime;
                    await showModalBottomSheet(
                      context: context,
                      builder: (ctx) => Container(
                        height: 300,
                        color: Colors.white,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("取消"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => selectedTime = tempDate);
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text("确定"),
                                ),
                              ],
                            ),
                            Expanded(
                              child: CupertinoDatePicker(
                                mode: CupertinoDatePickerMode.dateAndTime,
                                initialDateTime: selectedTime,
                                use24hFormat: true,
                                onDateTimeChanged: (val) => tempDate = val,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (titleController.text.isNotEmpty) {
                        Provider.of<AppProvider>(
                          context,
                          listen: false,
                        ).addCycleTask(
                          titleController.text,
                          frequency,
                          selectedTime,
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      "保存",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
