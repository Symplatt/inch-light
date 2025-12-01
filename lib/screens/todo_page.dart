import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/task_model.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_date_picker.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});
  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  bool showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final daily = provider.dailyTasks
        .where((t) => t.isCompleted == showCompleted)
        .toList();
    final normal = provider.normalTasks
        .where((t) => t.isCompleted == showCompleted)
        .toList();

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  FilterChipWidget(
                    text: "未完成",
                    selected: !showCompleted,
                    onTap: () => setState(() => showCompleted = false),
                  ),
                  const SizedBox(width: 12),
                  FilterChipWidget(
                    text: "已完成",
                    selected: showCompleted,
                    onTap: () => setState(() => showCompleted = true),
                  ),

                  const Spacer(),
                  InkWell(
                    onTap: () => _confirmClear(context, () {
                      provider.clearTodos(completedOnly: showCompleted);
                    }),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.delete_sweep_outlined,
                        size: 22,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (daily.isNotEmpty) ...[
                    const SectionHeader(title: "每日打卡"),
                    ...daily.map((t) => _buildTodoCard(t, provider)),
                    const SizedBox(height: 20),
                  ],
                  if (normal.isNotEmpty) ...[
                    const SectionHeader(title: "任务清单"),
                    ...normal.map((t) => _buildTodoCard(t, provider)),
                  ],
                  if (daily.isEmpty && normal.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 100),
                        child: Text(
                          "暂无任务",
                          style: TextStyle(color: Colors.grey[300]),
                        ),
                      ),
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),

        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            heroTag: "todo_add",
            backgroundColor: AppColors.textDark,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.add),
            onPressed: () => _showAddTodo(context),
          ),
        ),
      ],
    );
  }

  void _confirmClear(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("确认清空"),
        content: Text("确定清空所有${showCompleted ? "已完成" : "未完成"}的任务吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text("清空", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoCard(TaskItem task, AppProvider provider) {
    return Dismissible(
      key: Key(task.id),
      background: Container(
        color: Colors.red[100],
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => provider.deleteTodo(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: Row(
            children: [
              InkWell(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
                onTap: () => provider.toggleTodo(task),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: task.isCompleted
                          ? AppColors.primary
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: task.isCompleted
                            ? AppColors.primary
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: task.isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(16),
                  ),
                  onTap: () => _showEditTodo(context, provider, task),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            color: task.isCompleted
                                ? Colors.grey[400]
                                : AppColors.textDark,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.grey[400],
                          ),
                        ),
                        if (task.deadline != null || task.tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                if (task.deadline != null) ...[
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 12,
                                    color: task.isCompleted
                                        ? Colors.grey[300]
                                        : Colors.red[300],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat(
                                      'MM-dd HH:mm',
                                    ).format(task.deadline!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: task.isCompleted
                                          ? Colors.grey[300]
                                          : Colors.red[400],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                ...task.tags.map(
                                  (tag) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Text(
                                      "#$tag",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[400],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _showCustomDatePicker(
    BuildContext context, {
    DateTime? initialTime,
  }) async {
    DateTime tempDate = initialTime ?? DateTime.now();

    return await showDialog<DateTime>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 340,
          child: CustomDateTimePickerWidget(initialDate: tempDate),
        ),
      ),
    );
  }

  void _showEditTodo(
    BuildContext context,
    AppProvider provider,
    TaskItem task,
  ) {
    final tc = TextEditingController(text: task.title);
    final tagC = TextEditingController(text: task.tags.join(" "));
    DateTime? dead = task.deadline;

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
                "编辑任务",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: tc,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "任务名称",
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tagC,
                decoration: const InputDecoration(
                  labelText: "标签 (空格分隔)",
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: () async {
                  final result = await _showCustomDatePicker(
                    context,
                    initialTime: dead,
                  );
                  if (result != null) {
                    if (result.year == 0) {
                      setState(() => dead = null);
                    } else {
                      setState(() => dead = result);
                    }
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: dead == null
                            ? Colors.grey[400]
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        dead == null
                            ? "设置截止时间"
                            : DateFormat('yyyy-MM-dd HH:mm').format(dead!),
                        style: TextStyle(
                          color: dead == null
                              ? Colors.grey[500]
                              : AppColors.textDark,
                          fontWeight: dead == null
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (dead != null)
                        GestureDetector(
                          onTap: () => setState(() => dead = null),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey,
                          ),
                        )
                      else
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.grey,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    if (tc.text.isEmpty) return;
                    List<String> tags = tagC.text
                        .split(' ')
                        .where((s) => s.isNotEmpty)
                        .toList();
                    provider.updateTodoTask(task, tc.text, dead, tags);
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    "保存修改",
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

  void _showAddTodo(BuildContext context) {
    final tc = TextEditingController();
    final tagC = TextEditingController();
    TaskType type = TaskType.normal;
    DateTime? dead;

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
                "添加任务",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: tc,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "准备做什么？",
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
                    label: "每日打卡",
                    selected: type == TaskType.daily,
                    onTap: () => setState(() => type = TaskType.daily),
                  ),
                  const SizedBox(width: 12),
                  ModeChipWidget(
                    label: "普通待办",
                    selected: type == TaskType.normal,
                    onTap: () => setState(() => type = TaskType.normal),
                  ),
                ],
              ),
              if (type == TaskType.normal) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: tagC,
                  decoration: const InputDecoration(
                    labelText: "标签 (空格分隔)",
                    prefixIcon: Icon(Icons.tag),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final result = await _showCustomDatePicker(
                      context,
                      initialTime: dead,
                    );
                    if (result != null) {
                      if (result.year == 0) {
                        setState(() => dead = null);
                      } else {
                        setState(() => dead = result);
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          color: dead == null
                              ? Colors.grey[400]
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          dead == null
                              ? "设置截止时间"
                              : DateFormat('yyyy-MM-dd HH:mm').format(dead!),
                          style: TextStyle(
                            color: dead == null
                                ? Colors.grey[500]
                                : AppColors.textDark,
                            fontWeight: dead == null
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (dead != null)
                          GestureDetector(
                            onTap: () => setState(() => dead = null),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey,
                            ),
                          )
                        else
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    if (tc.text.isEmpty) return;
                    List<String> tags = tagC.text
                        .split(' ')
                        .where((s) => s.isNotEmpty)
                        .toList();
                    Provider.of<AppProvider>(
                      context,
                      listen: false,
                    ).addTodoTask(tc.text, type, deadline: dead, tags: tags);
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    "确认添加",
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
}
