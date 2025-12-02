import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/task_model.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_date_picker.dart'; // 引入自定义选择器

class CyclePage extends StatelessWidget {
  const CyclePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: provider.cycleTasks.isEmpty
                  ? Center(
                      child: Text(
                        "暂无周期提醒",
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                      children: [
                        const SectionHeader(title: "即将到来"),
                        ...provider.cycleTasks.map(
                          (t) => _buildCycleCard(context, t, provider),
                        ),
                      ],
                    ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            heroTag: "cycle_add",
            backgroundColor: AppColors.textDark,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.add),
            onPressed: () => _showCycleDialog(context, provider),
          ),
        ),
      ],
    );
  }

  Widget _buildCycleCard(
    BuildContext context,
    CycleTask task,
    AppProvider provider,
  ) {
    String typeStr = "";
    switch (task.frequency) {
      case CycleFrequency.daily:
        typeStr = "每天";
        break;
      case CycleFrequency.weekly:
        typeStr = "每周";
        break;
      case CycleFrequency.monthly:
        typeStr = "每月";
        break;
      case CycleFrequency.yearly:
        typeStr = "每年";
        break;
    }

    return Dismissible(
      key: Key(task.id),
      background: Container(
        color: Colors.red[100],
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => provider.deleteCycleTask(task.id),
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
        child: ListTile(
          onTap: () => _showCycleDialog(context, provider, task: task),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Text(
            task.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              "下次: ${DateFormat('yyyy-MM-dd HH:mm').format(task.nextRunTime)}",
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              typeStr,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 复用清单模块的日期选择器逻辑
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

  void _showCycleDialog(
    BuildContext context,
    AppProvider provider, {
    CycleTask? task,
  }) {
    final tc = TextEditingController(text: task?.title);
    // 【新增】创建焦点控制器
    final FocusNode focusNode = FocusNode();

    CycleFrequency freq = task?.frequency ?? CycleFrequency.daily;
    DateTime time = task?.time ?? DateTime.now();
    int? specificVal = task?.specificValue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
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
                Text(
                  task == null ? "新建周期" : "编辑周期",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: tc,
                  focusNode: focusNode, // 【新增】绑定焦点
                  autofocus: true, // 自动聚焦
                  decoration: InputDecoration(
                    hintText: "提醒什么事？",
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 频率选择
                DropdownButtonFormField<CycleFrequency>(
                  value: freq,
                  decoration: const InputDecoration(
                    labelText: "重复频率",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: CycleFrequency.daily,
                      child: Text("每天"),
                    ),
                    DropdownMenuItem(
                      value: CycleFrequency.weekly,
                      child: Text("每周"),
                    ),
                    DropdownMenuItem(
                      value: CycleFrequency.monthly,
                      child: Text("每月"),
                    ),
                    DropdownMenuItem(
                      value: CycleFrequency.yearly,
                      child: Text("每年"),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => freq = v!);
                    // 【新增】操作完后，光标移回输入框
                    focusNode.requestFocus();
                  },
                ),
                const SizedBox(height: 16),
                // 动态输入框
                Row(
                  children: [
                    if (freq == CycleFrequency.weekly)
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: specificVal ?? 1,
                          decoration: const InputDecoration(
                            labelText: "周几",
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(
                            7,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text("周${i + 1}"),
                            ),
                          ),
                          onChanged: (v) {
                            setState(() => specificVal = v);
                            // 【新增】操作完后，光标移回输入框
                            focusNode.requestFocus();
                          },
                        ),
                      ),
                    if (freq == CycleFrequency.monthly)
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: specificVal ?? 1,
                          decoration: const InputDecoration(
                            labelText: "几号",
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(
                            31,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text("${i + 1}号"),
                            ),
                          ),
                          onChanged: (v) {
                            setState(() => specificVal = v);
                            // 【新增】操作完后，光标移回输入框
                            focusNode.requestFocus();
                          },
                        ),
                      ),
                    if (freq == CycleFrequency.weekly ||
                        freq == CycleFrequency.monthly)
                      const SizedBox(width: 10),

                    // 时间选择器
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          // 弹出选择器
                          final result = await _showCustomDatePicker(
                            context,
                            initialTime: time,
                          );
                          if (result != null && result.year != 0) {
                            setState(() {
                              time = result;
                              // 智能联动：根据选择的日期，自动填入周几或几号
                              if (freq == CycleFrequency.weekly) {
                                specificVal = result.weekday;
                              } else if (freq == CycleFrequency.monthly) {
                                specificVal = result.day;
                              }
                            });
                          }
                          // 【新增】操作完后，光标移回输入框
                          focusNode.requestFocus();
                        },
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                freq == CycleFrequency.yearly
                                    ? DateFormat("MM-dd HH:mm").format(time)
                                    : DateFormat("HH:mm").format(time),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Icon(
                                Icons.access_time,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      if (tc.text.trim().isEmpty) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text("请确定名称")));
                        // 【新增】如果校验失败，也把光标拉回来
                        focusNode.requestFocus();
                        return;
                      }
                      if (task == null) {
                        provider.addCycleTask(tc.text, freq, time, specificVal);
                      } else {
                        provider.updateCycleTask(
                          task,
                          tc.text,
                          freq,
                          time,
                          specificVal,
                        );
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text("保存"),
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
