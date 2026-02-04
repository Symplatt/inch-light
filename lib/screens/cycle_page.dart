import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/app_provider.dart';
import '../models/task_model.dart';

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
          appBar: AppBar(title: const Text('周期提醒')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader("今天"),
              if (todayTasks.isEmpty) _buildEmptyState(),
              ...todayTasks.map((t) => _buildCycleTile(context, t, provider)),

              _buildSectionHeader("明天"),
              if (tomorrowTasks.isEmpty) _buildEmptyState(),
              ...tomorrowTasks.map(
                (t) => _buildCycleTile(context, t, provider),
              ),

              _buildSectionHeader("未来"),
              if (futureTasks.isEmpty) _buildEmptyState(),
              ...futureTasks.map((t) => _buildCycleTile(context, t, provider)),

              const SizedBox(height: 80),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddCycleDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: Text("暂无任务", style: TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildCycleTile(
    BuildContext context,
    CycleTask task,
    AppProvider provider,
  ) {
    return Card(
      child: ListTile(
        title: Text(task.title),
        subtitle: Text(
          "${task.frequency.name} | 下次: ${DateFormat('MM-dd HH:mm').format(task.nextRunTime)}",
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => provider.removeCycleTask(task),
        ),
      ),
    );
  }

  void _showAddCycleDialog(BuildContext context) {
    // 这里需要根据原来的 CycleTask 创建逻辑补充完整 Dialog
    // 为保持简洁，暂且调用 provider.addCycleTask 模拟
    // 实际项目中应弹出一个包含频率选择、时间选择的完整对话框
    final titleController = TextEditingController();
    CycleFrequency frequency = CycleFrequency.daily;
    DateTime selectedTime = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("新建周期任务"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "任务名称"),
                ),
                DropdownButton<CycleFrequency>(
                  value: frequency,
                  items: CycleFrequency.values.map((e) {
                    return DropdownMenuItem(value: e, child: Text(e.name));
                  }).toList(),
                  onChanged: (val) => setState(() => frequency = val!),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (t != null) {
                      final now = DateTime.now();
                      setState(() {
                        selectedTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          t.hour,
                          t.minute,
                        );
                      });
                    }
                  },
                  child: Text(DateFormat('HH:mm').format(selectedTime)),
                ),
              ],
            ),
            actions: [
              TextButton(
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
                child: const Text("保存"),
              ),
            ],
          );
        },
      ),
    );
  }
}
