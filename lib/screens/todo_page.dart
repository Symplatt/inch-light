import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../providers/app_provider.dart';
import '../models/task_model.dart';
import '../constants/app_colors.dart';

class TodoPage extends StatelessWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final looseTasks = provider.looseTasks;
        final collections = provider.collections;

        return Scaffold(
          appBar: AppBar(
            title: const Text('待办清单'),
            actions: [
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: () => _showAddCollectionDialog(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 渲染合集列表
              ...collections.map((collection) {
                final tasksInCollection = provider.getTasksInCollection(
                  collection.id,
                );
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    key: Key(collection.id),
                    initiallyExpanded: collection.isExpanded,
                    onExpansionChanged: (expanded) {
                      provider.toggleCollectionExpand(collection.id);
                    },
                    title: Text(
                      "${collection.title} (${tasksInCollection.length})",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        _showAddTaskDialog(
                          context,
                          collectionId: collection.id,
                        );
                      },
                    ),
                    children: tasksInCollection
                        .map((task) => _buildTaskItem(context, task, provider))
                        .toList(),
                  ),
                );
              }), // 修复：这里之前可能多了一个 .toList()，...map 展开不需要 toList

              if (collections.isNotEmpty) const Divider(),

              if (looseTasks.isNotEmpty || collections.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("其他任务", style: TextStyle(color: Colors.grey)),
                ),

              // 渲染散装任务
              ...looseTasks.map(
                (task) => _buildTaskItem(context, task, provider),
              ),

              const SizedBox(height: 80),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddTaskDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(
    BuildContext context,
    TaskItem task,
    AppProvider provider,
  ) {
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (val) {
            provider.toggleTaskCompletion(task);
          },
        ),
        title: Text(
          task.title,
          maxLines: null,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey : Colors.black,
          ),
        ),
        subtitle: task.deadline != null
            ? Text(
                DateFormat('MM-dd HH:mm').format(task.deadline!),
                style: const TextStyle(fontSize: 12),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                task.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: task.isPinned ? AppColors.primary : Colors.grey,
              ),
              onPressed: () => provider.toggleTaskPin(task),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => provider.removeTask(task),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCollectionDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("新建合集"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "合集名称"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Provider.of<AppProvider>(
                  context,
                  listen: false,
                ).addCollection(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text("创建"),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, {String? collectionId}) {
    final titleController = TextEditingController();
    DateTime? selectedDeadline;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(collectionId != null ? "新建合集任务" : "新建任务"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(labelText: "任务名称"),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      selectedDeadline == null
                          ? "无截止时间"
                          : DateFormat('MM-dd HH:mm').format(selectedDeadline!),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          final newTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            23,
                            59,
                          );
                          setState(() {
                            selectedDeadline = newTime;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("取消"),
              ),
              TextButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty) {
                    final newTask = TaskItem(
                      id: const Uuid().v4(),
                      title: titleController.text,
                      type: TaskType.normal,
                      deadline: selectedDeadline,
                      collectionId: collectionId,
                    );
                    Provider.of<AppProvider>(
                      context,
                      listen: false,
                    ).addTaskToCollection(newTask, collectionId);
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
