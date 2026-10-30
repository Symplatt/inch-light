import '../widgets/app_dialog.dart';
import '../widgets/todo_visibility_dialog.dart';
import '../widgets/position_border.dart';
import '../widgets/section_heading.dart';
import '../widgets/task_action_dialog.dart';
import '../widgets/date_time_sheet.dart';
import '../widgets/deadline_label.dart';
import '../widgets/swipe_delete_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/app_provider.dart';
import '../models/task_model.dart';
import '../constants/app_colors.dart';
import '../utils/deadline.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  // 视图状态 (默认显示未完成)
  bool _showCompleted = false;
  static const _completionDuration = Duration(milliseconds: 320);
  static const _collectionCompletionDuration = Duration(milliseconds: 520);
  final Set<String> _completing = {};
  final Set<String> _completingCollections = {};

  Future<void> _completeTask(TaskItem task, AppProvider provider) async {
    if (_completing.contains(task.id)) return;
    if (task.isCompleted) {
      provider.toggleTaskCompletion(task);
      return;
    }
    final collectionId = task.collectionId;
    var completesCollection = false;
    setState(() {
      _completing.add(task.id);
      if (collectionId != null &&
          !provider.collections
              .firstWhere((c) => c.id == collectionId)
              .isFixed &&
          provider.normalTasks
              .where((item) => item.collectionId == collectionId)
              .every(
                (item) => item.isCompleted || _completing.contains(item.id),
              )) {
        completesCollection = true;
      }
    });
    await Future<void>.delayed(_completionDuration);
    if (!mounted) return;
    // Keep the last completed item pending until the collection has faded out.
    if (completesCollection) {
      setState(() => _completingCollections.add(collectionId!));
      await Future<void>.delayed(_collectionCompletionDuration);
    }
    if (!mounted) return;
    provider.toggleTaskCompletion(task);
    setState(() {
      _completing.remove(task.id);
      if (completesCollection) _completingCollections.remove(collectionId);
    });
  }

  Future<void> _chooseVisible(AppProvider provider) async {
    final selected = provider.collections
        .where((c) => provider.isTodoCollectionVisible(c.id))
        .map((c) => c.id)
        .toSet();
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => TodoVisibilityDialog(
        collections: provider.orderedCollections,
        visible: selected,
      ),
    );
    if (!mounted || result == null) return;
    await provider.setVisibleTodoCollections(result);
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final collections = provider.orderedCollections;
        // 获取排序后、并按完成状态过滤的日常打卡
        final dailyTasks = provider.getDailyTasks(isCompleted: _showCompleted);
        final looseTasks = provider.getLooseTasks(isCompleted: _showCompleted);

        final looseSection = <Widget>[
          _buildSectionHeader("零散事项"),
          if (looseTasks.isEmpty && collections.isEmpty && dailyTasks.isEmpty)
            _buildEmptyState(),
          ...looseTasks.map((task) => _buildTaskItem(context, task, provider)),

          const SizedBox(height: 20),
        ];
        final collectionSection = <Widget>[
          if (collections.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: SectionHeading(
                    title: '事项合集',
                    fontSize: 18,
                    count: collections.length,
                  ),
                ),
                IconButton(
                  tooltip: '部分显示',
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerRight,
                  icon: Icon(
                    Icons.filter_list,
                    color:
                        collections.any(
                          (c) => !provider.isTodoCollectionVisible(c.id),
                        )
                        ? AppColors.textGrey
                        : const Color(0xFF989BA1),
                  ),
                  onPressed: () => _chooseVisible(provider),
                ),
              ],
            ),
            ...collections
                .where((c) => provider.isTodoCollectionVisible(c.id))
                .map((collection) {
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
        ];

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            actionsPadding: const EdgeInsets.only(right: 8),
            backgroundColor: AppColors.bg,
            elevation: 0,
            centerTitle: false,
            title: Text(_showCompleted ? '已完成待办' : '待办'),
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

              if (provider.looseTasksFirst) ...[
                ...looseSection,
                ...collectionSection,
              ] else ...[
                ...collectionSection,
                ...looseSection,
              ],

              const SizedBox(height: 80),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.primary,
            tooltip: '新建',
            onPressed: () => _showAddTaskDialog(context),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onClear}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: AppColors.textDark,
            ),
          ),
          if (onClear != null)
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
    final nearest = provider.nearestDeadline(collection.id);
    return AnimatedOpacity(
      opacity: _completingCollections.contains(collection.id) ? 0 : 1,
      duration: _collectionCompletionDuration,
      child: GestureDetector(
        onLongPress: () =>
            _showCollectionActions(context, collection, provider),
        child: SwipeDeleteCard(
          key: Key(collection.id),
          id: collection.id,
          bottomMargin: 16,
          direction: DismissDirection.horizontal,
          onSwipedRight: () async {
            await provider.setVisibleTodoCollections({
              for (final item in provider.collections)
                if (item.id != collection.id &&
                    provider.isTodoCollectionVisible(item.id))
                  item.id,
            });
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(const SnackBar(content: Text('已取消显示')));
          },
          onDeleted: () => provider.removeCollection(collection.id),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Material(
              clipBehavior: Clip.antiAlias,
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey('${collection.id}-${collection.isExpanded}'),
                  initiallyExpanded: collection.isExpanded,
                  onExpansionChanged: (_) =>
                      provider.toggleCollectionExpand(collection.id),
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  subtitle: nearest == null
                      ? null
                      : DeadlineLabel(
                          deadline: nearest,
                          pattern: 'yyyy-MM-dd HH:mm',
                        ),
                  title: Text(
                    collection.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      decoration: _completingCollections.contains(collection.id)
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.add,
                      size: 24,
                      color: AppColors.primary,
                    ),
                    onPressed: () => _showAddTaskDialog(
                      context,
                      collectionId: collection.id,
                    ),
                  ),
                  children: [
                    const Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Color(0xFFEEEEEE),
                      indent: 16,
                      endIndent: 16,
                    ),
                    for (var i = 0; i < tasks.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          thickness: 0.5,
                          color: AppColors.divider,
                          indent: 16,
                          endIndent: 16,
                        ),
                      _buildTaskItem(
                        context,
                        tasks[i],
                        provider,
                        inCollection: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
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
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
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
                      fontWeight: FontWeight.w400,
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
    AppProvider provider, {
    bool inCollection = false,
  }) {
    final completing = _completing.contains(task.id);
    final checked = task.isCompleted || completing;
    return AnimatedOpacity(
      opacity: completing ? 0 : 1,
      duration: _completionDuration,
      child: SwipeDeleteCard(
        key: ValueKey('task-card-${task.id}'),
        enabled: !inCollection,
        id: task.id,
        radius: inCollection ? 0 : 16,
        bottomMargin: inCollection ? 0 : 12,
        onDeleted: () => provider.removeTask(task),
        child: Container(
          decoration: inCollection
              ? const BoxDecoration(color: AppColors.surface)
              : ShapeDecoration(
                  color: AppColors.surface,
                  shape: PositionBorder(
                    pinned: task.isPinned,
                    bottom: task.isBottom,
                    radius: inCollection ? 0 : 16,
                  ),
                ),
          child: InkWell(
            onLongPress: () => _showEditTaskDialog(context, task),
            borderRadius: BorderRadius.circular(inCollection ? 0 : 16),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: GestureDetector(
                onTap: () => _completeTask(task, provider),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: checked ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: checked ? AppColors.primary : AppColors.textGrey,
                      width: 1.4,
                    ),
                  ),
                  child: checked
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              trailing: task.isPinned || task.isBottom
                  ? Icon(
                      task.isPinned
                          ? Icons.vertical_align_top
                          : Icons.vertical_align_bottom,
                      size: 18,
                      color: AppColors.textGrey,
                    )
                  : null,
              titleAlignment: ListTileTitleAlignment.center,
              title: Text(
                task.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  decoration: checked ? TextDecoration.lineThrough : null,
                  color: checked ? AppColors.textGrey : AppColors.textDark,
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
                            child: DeadlineLabel(
                              deadline: task.deadline!,
                              blue: task.deadlineBlue,
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
                                        color: const Color(0xFFF8F8FA),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tag,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF9699A0),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCollectionActions(
    BuildContext context,
    TaskCollection collection,
    AppProvider provider,
  ) {
    showTaskActionDialog(
      context,
      title: collection.title,
      actions: [
        TaskAction(
          label: '修改合集名称',
          icon: Icons.drive_file_rename_outline,
          onTap: () =>
              _showRenameCollectionDialog(context, collection: collection),
        ),
        TaskAction(
          label: '一键完成所有事项',
          icon: Icons.done_all_rounded,
          onTap: () => provider.completeCollection(collection.id),
        ),
        TaskAction(
          label: collection.isFixed ? '取消固定' : '固定合集',
          icon: Icons.push_pin_outlined,
          onTap: () => provider.toggleCollectionFixed(collection.id),
        ),
      ],
    );
  }

  Future<void> _moveTask(BuildContext context, TaskItem task) async {
    final provider = context.read<AppProvider>();
    final destination = await showDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('移动事项'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final destination in [
                  (id: '', title: '零散事项'),
                  ...provider.collections.map(
                    (c) => (id: c.id, title: c.title),
                  ),
                ])
                  ListTile(
                    title: Text(destination.title),
                    trailing: (task.collectionId ?? '') == destination.id
                        ? const Icon(Icons.check, size: 20)
                        : null,
                    onTap: () => Navigator.pop(ctx, destination.id),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (destination != null)
      provider.moveTask(task, destination.isEmpty ? null : destination);
  }

  void _showEditTaskDialog(BuildContext context, TaskItem task) {
    final titleController = TextEditingController(text: task.title);
    final tagController = TextEditingController(text: task.tags.join(" "));
    DateTime? selectedDeadline = task.deadline;
    bool deadlineBlue = task.deadlineBlue;
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Text(
                          '编辑事项',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (task.type != TaskType.daily)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('移动'),
                          onPressed: () => _moveTask(context, task),
                        ),
                      if (task.type != TaskType.daily)
                        for (final position in [-1, 1])
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: EdgeInsets.only(
                                left: 8,
                                right: position == 1 ? 0 : 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => setState(() {
                              final active = position < 0
                                  ? task.isPinned
                                  : task.isBottom;
                              context.read<AppProvider>().setTaskPosition(
                                task,
                                active ? 0 : position,
                              );
                            }),
                            child: Text(
                              position < 0
                                  ? (task.isPinned ? '取消置顶' : '置顶')
                                  : (task.isBottom ? '取消置底' : '置底'),
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    minLines: 1,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: "事项内容",
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
                        prefixIconConstraints: const BoxConstraints.tightFor(
                          width: 38,
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12, right: 8),
                          child: Icon(Icons.tag, size: 18),
                        ),
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
                        await _showDateTimePicker(
                          context,
                          selectedDeadline ??
                              DateUtils.dateOnly(
                                DateTime.now(),
                              ).add(const Duration(hours: 23, minutes: 59)),
                          (dateTime) {
                            setState(() => selectedDeadline = dateTime);
                          },
                        );
                      },
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                            const SizedBox(width: 12),
                            Text(
                              selectedDeadline == null
                                  ? "设置截止时间"
                                  : DateFormat(
                                      'yyyy-MM-dd HH:mm',
                                    ).format(selectedDeadline!),
                              style: TextStyle(
                                color: selectedDeadline == null
                                    ? AppColors.textGrey
                                    : deadlineBlue
                                    ? const Color(0xFF5787B5)
                                    : AppColors.primary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const Spacer(),
                            if (selectedDeadline != null)
                              IconButton(
                                tooltip: '取消截止日期',
                                constraints: const BoxConstraints.tightFor(
                                  width: 28,
                                  height: 28,
                                ),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () =>
                                    setState(() => selectedDeadline = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final offset in [0, 1]) ...[
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                            onPressed: () => setState(() {
                              selectedDeadline = endOfDay(offset);
                            }),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.today_outlined, size: 18),
                                const SizedBox(width: 4),
                                Text(offset == 0 ? '今日截止' : '明日截止'),
                              ],
                            ),
                          ),
                          if (offset == 0) const SizedBox(width: 12),
                        ],
                        const Spacer(),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: deadlineBlue
                                ? const Color(0xFF5787B5)
                                : AppColors.textGrey,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () =>
                              setState(() => deadlineBlue = !deadlineBlue),
                          child: const Text('时间标蓝'),
                        ),
                      ],
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
                            deadlineBlue: deadlineBlue,
                            newTags: tags,
                          );
                          Navigator.pop(context);
                        }
                      },
                      child: const Text(
                        "保存修改",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _taskTypeChip(String label, bool selected, VoidCallback onSelected) =>
      ChoiceChip(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        showCheckmark: false,
        pressElevation: 0,
        chipAnimationStyle: ChipAnimationStyle(
          enableAnimation: AnimationStyle.noAnimation,
          selectAnimation: AnimationStyle.noAnimation,
          avatarDrawerAnimation: AnimationStyle.noAnimation,
          deleteDrawerAnimation: AnimationStyle.noAnimation,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 18, color: Color(0xFF404040)),
              const SizedBox(width: 4),
            ],
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => onSelected(),
      );

  void _showAddTaskDialog(BuildContext context, {String? collectionId}) {
    final titleController = TextEditingController();
    final tagController = TextEditingController();
    bool isDaily = false;
    bool isCollection = false;
    DateTime? selectedDeadline;
    bool deadlineBlue = false;
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "新建",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 20),
                  if (collectionId == null)
                    ChipTheme(
                      data: ChipTheme.of(context).copyWith(
                        backgroundColor: const Color(0xFFF7F7F7),
                        selectedColor: const Color(0xFFE3E3E3),
                        secondarySelectedColor: const Color(0xFFE3E3E3),
                        labelStyle: const TextStyle(color: Color(0xFF606060)),
                        secondaryLabelStyle: const TextStyle(
                          color: Color(0xFF404040),
                        ),
                        checkmarkColor: const Color(0xFF404040),
                        side: const BorderSide(color: Color(0xFFC7C7C7)),
                        surfaceTintColor: Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          _taskTypeChip(
                            '普通事项',
                            !isDaily && !isCollection,
                            () => setState(() {
                              isDaily = false;
                              isCollection = false;
                            }),
                          ),
                          const SizedBox(width: 10),
                          _taskTypeChip(
                            '每日打卡',
                            isDaily,
                            () => setState(() {
                              isDaily = true;
                              isCollection = false;
                            }),
                          ),
                          const SizedBox(width: 10),
                          _taskTypeChip(
                            '合集',
                            isCollection,
                            () => setState(() {
                              isDaily = false;
                              isCollection = true;
                            }),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    keyboardType: isCollection
                        ? TextInputType.text
                        : TextInputType.multiline,
                    textInputAction: isCollection
                        ? TextInputAction.done
                        : TextInputAction.newline,
                    minLines: 1,
                    maxLines: isCollection ? 1 : 6,
                    decoration: InputDecoration(
                      hintText: isCollection ? '合集名称' : '准备做什么？',
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (!isDaily && !isCollection) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: tagController,
                      decoration: InputDecoration(
                        hintText: "添加标签 (空格分隔)",
                        prefixIconConstraints: const BoxConstraints.tightFor(
                          width: 38,
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12, right: 8),
                          child: Icon(Icons.tag, size: 18),
                        ),
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
                        await _showDateTimePicker(
                          context,
                          selectedDeadline ??
                              DateUtils.dateOnly(
                                DateTime.now(),
                              ).add(const Duration(hours: 23, minutes: 59)),
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
                            const SizedBox(width: 12),
                            Text(
                              selectedDeadline == null
                                  ? "设置截止时间"
                                  : DateFormat(
                                      'yyyy-MM-dd HH:mm',
                                    ).format(selectedDeadline!),
                              style: TextStyle(
                                color: selectedDeadline == null
                                    ? AppColors.textGrey
                                    : deadlineBlue
                                    ? const Color(0xFF5787B5)
                                    : AppColors.primary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const Spacer(),
                            if (selectedDeadline != null)
                              IconButton(
                                tooltip: '取消截止日期',
                                constraints: const BoxConstraints.tightFor(
                                  width: 28,
                                  height: 28,
                                ),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () =>
                                    setState(() => selectedDeadline = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final offset in [0, 1])
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                            icon: const Icon(Icons.today_outlined, size: 18),
                            label: Text(offset == 0 ? '今日截止' : '明日截止'),
                            onPressed: () => setState(() {
                              selectedDeadline = endOfDay(offset);
                            }),
                          ),
                        const Spacer(),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: deadlineBlue
                                ? const Color(0xFF5787B5)
                                : AppColors.textGrey,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () =>
                              setState(() => deadlineBlue = !deadlineBlue),
                          child: const Text('时间标蓝'),
                        ),
                      ],
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
                        final title = titleController.text.trim();
                        if (title.isNotEmpty) {
                          if (isCollection) {
                            context.read<AppProvider>().addCollection(title);
                          } else if (isDaily) {
                            Provider.of<AppProvider>(
                              context,
                              listen: false,
                            ).addDailyTask(title);
                          } else {
                            Provider.of<AppProvider>(
                              context,
                              listen: false,
                            ).addNormalTask(
                              title,
                              deadline: selectedDeadline,
                              deadlineBlue: deadlineBlue,
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
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDateTimePicker(
    BuildContext context,
    DateTime initialTime,
    Function(DateTime) onConfirm,
  ) async {
    final selected = await showDateTimeSheet(context, initialDate: initialTime);
    if (selected != null && mounted) onConfirm(selected);
  }

  void _showRenameCollectionDialog(
    BuildContext context, {
    required TaskCollection collection,
  }) {
    final controller = TextEditingController(text: collection.title);
    showDialog(
      context: context,
      builder: (context) => AppAlertDialog(
        title: const Text('修改合集名称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "合集名称"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                final provider = context.read<AppProvider>();
                provider.renameCollection(collection.id, title);
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
