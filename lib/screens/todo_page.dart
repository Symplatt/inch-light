import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/app_provider.dart';
import '../models/task_model.dart';
import '../constants/app_colors.dart';
import 'main_screen.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  // 视图状态 (默认显示未完成)
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final collections = provider.collections;
        // 获取排序后、并按完成状态过滤的日常打卡
        final dailyTasks = provider.getDailyTasks(isCompleted: _showCompleted);
        final looseTasks = provider.getLooseTasks(isCompleted: _showCompleted);

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            centerTitle: false,
            title: Text(
              _showCompleted ? '已完成清单' : '待办清单',
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _showCompleted ? Icons.check_circle : Icons.circle_outlined,
                  color: _showCompleted
                      ? AppColors.success
                      : AppColors.textGrey,
                ),
                tooltip: _showCompleted ? "查看待办" : "查看已完成",
                onPressed: () {
                  setState(() {
                    _showCompleted = !_showCompleted;
                  });
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.create_new_folder_outlined,
                  color: AppColors.textDark,
                ),
                onPressed: () => _showAddCollectionDialog(context),
              ),
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
              // --- 1. 日常打卡区域 ---
              if (dailyTasks.isNotEmpty) ...[
                _buildSectionHeader(
                  "日常打卡",
                  // 点击右侧按钮，清空当前视图下的所有日常打卡
                  onClear: () =>
                      provider.clearDailyTasks(isCompleted: _showCompleted),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: dailyTasks
                        .map(
                          (task) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _buildDailyCard(context, task, provider),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // --- 2. 任务合集 ---
              if (collections.isNotEmpty) ...[
                _buildSectionHeader(
                  "任务合集",
                  // 合集本身不分完成/未完成，这里设为点击即清空所有合集（释放任务）
                  onClear: () => provider.clearCollections(),
                ),
                ...collections.map((collection) {
                  final tasks = provider.getTasksInCollection(
                    collection.id,
                    isCompleted: _showCompleted,
                  );
                  return _buildCollectionCard(
                    context,
                    collection,
                    tasks,
                    provider,
                  );
                }),
                const SizedBox(height: 20),
              ],

              // --- 3. 散落任务 ---
              _buildSectionHeader(
                "零散任务",
                // 清空当前视图下的所有散落任务
                onClear: () =>
                    provider.clearLooseTasks(isCompleted: _showCompleted),
              ),
              if (looseTasks.isEmpty &&
                  collections.isEmpty &&
                  dailyTasks.isEmpty)
                _buildEmptyState(),
              ...looseTasks.map(
                (task) => _buildTaskItem(context, task, provider),
              ),

              const SizedBox(height: 80),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.primary,
            onPressed: () => _showAddTaskDialog(context),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  // 需求2：修改 Header 增加删除按钮
  Widget _buildSectionHeader(String title, {required VoidCallback onClear}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_sweep,
              color: AppColors.textGrey,
              size: 20,
            ),
            onPressed: onClear,
            tooltip: "清空此项",
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: const [
            Icon(Icons.inbox_outlined, size: 60, color: Color(0xFFE0E0E0)),
            SizedBox(height: 10),
            Text("空空如也", style: TextStyle(color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionCard(
    BuildContext context,
    TaskCollection collection,
    List<TaskItem> tasks,
    AppProvider provider,
  ) {
    return Dismissible(
      key: Key(collection.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => provider.removeCollection(collection.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.shadow,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: collection.isExpanded,
            onExpansionChanged: (_) =>
                provider.toggleCollectionExpand(collection.id),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: Text(
              collection.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add, size: 24, color: AppColors.primary),
              onPressed: () =>
                  _showAddTaskDialog(context, collectionId: collection.id),
            ),
            children: [
              const Divider(
                height: 1,
                thickness: 0.5,
                color: Color(0xFFEEEEEE),
                indent: 16,
                endIndent: 16,
              ),
              ...tasks
                  .map((t) => _buildTaskItem(context, t, provider))
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyCard(
    BuildContext context,
    TaskItem task,
    AppProvider provider,
  ) {
    // 需求1：上下滑动删除 (vertical)
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.vertical,
      onDismissed: (_) => provider.removeTask(task),
      background: Container(color: Colors.transparent),
      child: GestureDetector(
        onTap: () => provider.toggleTaskCompletion(task),
        onLongPress: () => _showEditTaskDialog(context, task),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: task.isCompleted
                ? AppColors.success.withOpacity(0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: task.isCompleted ? AppColors.success : Colors.transparent,
              width: 2,
            ),
            boxShadow: AppColors.shadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                color: task.isCompleted
                    ? AppColors.success
                    : AppColors.textGrey,
                size: 28,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: task.isCompleted
                          ? AppColors.success
                          : AppColors.textDark,
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

  Widget _buildTaskItem(
    BuildContext context,
    TaskItem task,
    AppProvider provider,
  ) {
    Color dateColor = AppColors.textGrey;
    if (task.deadline != null) {
      if (task.deadline!.isBefore(DateTime.now())) {
        dateColor = AppColors.danger;
      } else {
        dateColor = AppColors.success;
      }
    }

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => provider.removeTask(task),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.shadow,
        ),
        child: InkWell(
          onLongPress: () => _showEditTaskDialog(context, task),
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: GestureDetector(
              onTap: () => provider.toggleTaskCompletion(task),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? AppColors.primary
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: task.isCompleted
                        ? AppColors.primary
                        : AppColors.textGrey,
                    width: 2,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                decoration: task.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
                color: task.isCompleted
                    ? AppColors.textGrey
                    : AppColors.textDark,
              ),
            ),
            subtitle: (task.deadline == null && task.tags.isEmpty)
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.deadline != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: dateColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat(
                                  'MM-dd HH:mm',
                                ).format(task.deadline!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dateColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (task.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 6,
                            children: task.tags
                                .map(
                                  (tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.bg,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      tag,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ],
                  ),
            trailing: IconButton(
              icon: Icon(
                task.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: task.isPinned
                    ? AppColors.primary
                    : AppColors.textGrey.withOpacity(0.3),
              ),
              onPressed: () => provider.toggleTaskPin(task),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, TaskItem task) {
    final titleController = TextEditingController(text: task.title);
    final tagController = TextEditingController(text: task.tags.join(" "));
    DateTime? selectedDeadline = task.deadline;
    List<String> tags = List.from(task.tags);

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
                  "编辑任务",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "任务内容",
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                if (task.type != TaskType.daily) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: tagController,
                    decoration: InputDecoration(
                      hintText: "标签 (空格分隔)",
                      prefixIcon: const Icon(Icons.tag, size: 18),
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) {
                      tags = v.split(' ').where((e) => e.isNotEmpty).toList();
                    },
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      await _showCupertinoDatePicker(
                        context,
                        selectedDeadline ?? DateTime.now(),
                        (dateTime) {
                          setState(() => selectedDeadline = dateTime);
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: AppColors.textGrey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedDeadline == null
                                ? "设置截止时间"
                                : DateFormat(
                                    'yyyy-MM-dd HH:mm',
                                  ).format(selectedDeadline!),
                            style: TextStyle(
                              color: selectedDeadline == null
                                  ? AppColors.textGrey
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                        ).updateTask(
                          task,
                          titleController.text,
                          newDeadline: selectedDeadline,
                          newTags: tags,
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      "保存修改",
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

  void _showAddTaskDialog(BuildContext context, {String? collectionId}) {
    final titleController = TextEditingController();
    final tagController = TextEditingController();
    bool isDaily = false;
    DateTime? selectedDeadline;
    List<String> tags = [];

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "新建",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if (collectionId == null)
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text("普通任务"),
                        selected: !isDaily,
                        onSelected: (v) => setState(() => isDaily = false),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("每日打卡"),
                        selected: isDaily,
                        onSelected: (v) => setState(() => isDaily = true),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "准备做什么？",
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (!isDaily) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: tagController,
                    decoration: InputDecoration(
                      hintText: "添加标签 (空格分隔)",
                      prefixIcon: const Icon(Icons.tag, size: 18),
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) {
                      tags = v.split(' ').where((e) => e.isNotEmpty).toList();
                    },
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      await _showCupertinoDatePicker(context, DateTime.now(), (
                        dateTime,
                      ) {
                        setState(() => selectedDeadline = dateTime);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: AppColors.textGrey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedDeadline == null
                                ? "设置截止时间 (默认23:59)"
                                : DateFormat(
                                    'yyyy-MM-dd HH:mm',
                                  ).format(selectedDeadline!),
                            style: TextStyle(
                              color: selectedDeadline == null
                                  ? AppColors.textGrey
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                        if (isDaily) {
                          Provider.of<AppProvider>(
                            context,
                            listen: false,
                          ).addDailyTask(titleController.text);
                        } else {
                          Provider.of<AppProvider>(
                            context,
                            listen: false,
                          ).addNormalTask(
                            titleController.text,
                            deadline: selectedDeadline,
                            collectionId: collectionId,
                            tags: tags,
                          );
                        }
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      "完成",
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

  Future<void> _showCupertinoDatePicker(
    BuildContext context,
    DateTime initialTime,
    Function(DateTime) onConfirm,
  ) async {
    final now = DateTime.now();
    DateTime tempDate = DateTime(now.year, now.month, now.day, 23, 59);
    if (initialTime.year != now.year ||
        initialTime.month != now.month ||
        initialTime.day != now.day) {
      tempDate = initialTime;
    }
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
                    onConfirm(tempDate);
                    Navigator.pop(ctx);
                  },
                  child: const Text("确定"),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: tempDate,
                use24hFormat: true,
                onDateTimeChanged: (val) => tempDate = val,
              ),
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
          decoration: const InputDecoration(hintText: "合集名称"),
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
}
