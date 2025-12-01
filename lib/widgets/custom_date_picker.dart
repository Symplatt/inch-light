import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class CustomDateTimePickerWidget extends StatefulWidget {
  final DateTime initialDate;
  const CustomDateTimePickerWidget({super.key, required this.initialDate});

  @override
  State<CustomDateTimePickerWidget> createState() =>
      _CustomDateTimePickerWidgetState();
}

class _CustomDateTimePickerWidgetState
    extends State<CustomDateTimePickerWidget> {
  late int selectedYear;
  late int selectedMonth;
  late int selectedDay;
  late int selectedHour;
  late int selectedMinute;

  final FixedExtentScrollController _yearCtrl = FixedExtentScrollController();
  final FixedExtentScrollController _monthCtrl = FixedExtentScrollController();
  final FixedExtentScrollController _dayCtrl = FixedExtentScrollController();
  final FixedExtentScrollController _hourCtrl = FixedExtentScrollController();
  final FixedExtentScrollController _minuteCtrl = FixedExtentScrollController();

  final int minYear = 2020;
  final int maxYear = 2030;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
    selectedMonth = widget.initialDate.month;
    selectedDay = widget.initialDate.day;
    selectedHour = widget.initialDate.hour;
    selectedMinute = widget.initialDate.minute;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _yearCtrl.jumpToItem(selectedYear - minYear);
      _monthCtrl.jumpToItem(selectedMonth - 1);
      _dayCtrl.jumpToItem(selectedDay - 1);
      _hourCtrl.jumpToItem(selectedHour);
      _minuteCtrl.jumpToItem(selectedMinute);
    });
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 2) {
      final bool isLeap =
          (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    const List<int> days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month];
  }

  Widget _buildPicker(
    FixedExtentScrollController controller,
    List<int> items,
    ValueChanged<int> onChanged,
  ) {
    return Expanded(
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 40,
        magnification: 1.1,
        useMagnifier: true,
        backgroundColor: Colors.transparent,
        selectionOverlay: const _CustomSelectionOverlay(),
        onSelectedItemChanged: (index) {
          onChanged(items[index]);
          HapticFeedback.selectionClick();
        },
        children: items
            .map(
              (e) => Center(
                child: Text(
                  e.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(selectedYear, selectedMonth);
    // 修正日期溢出
    if (selectedDay > daysInMonth) selectedDay = daysInMonth;

    return Container(
      height: 420,
      padding: const EdgeInsets.only(top: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "设置日期和时间",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 30),

          // 年 月 日
          SizedBox(
            height: 120,
            child: Row(
              children: [
                const SizedBox(width: 20),
                _buildPicker(
                  _yearCtrl,
                  List.generate(maxYear - minYear + 1, (i) => minYear + i),
                  (val) => setState(() => selectedYear = val),
                ),
                const SizedBox(width: 10),
                _buildPicker(
                  _monthCtrl,
                  List.generate(12, (i) => i + 1),
                  (val) => setState(() => selectedMonth = val),
                ),
                const SizedBox(width: 10),
                _buildPicker(
                  _dayCtrl,
                  List.generate(daysInMonth, (i) => i + 1),
                  (val) => setState(() => selectedDay = val),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),

          const SizedBox(height: 20), // 中间留白
          // 时 分
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                _buildPicker(
                  _hourCtrl,
                  List.generate(24, (i) => i),
                  (val) => setState(() => selectedHour = val),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    ":",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildPicker(
                  _minuteCtrl,
                  List.generate(60, (i) => i),
                  (val) => setState(() => selectedMinute = val),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),

          const Spacer(),

          // 底部按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                TextButton(
                  onPressed: () {
                    // 返回特殊的 Year=0 表示清除
                    Navigator.pop(context, DateTime(0));
                  },
                  child: const Text(
                    "清除",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "取消",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () {
                    final date = DateTime(
                      selectedYear,
                      selectedMonth,
                      selectedDay,
                      selectedHour,
                      selectedMinute,
                    );
                    Navigator.pop(context, date);
                  },
                  child: const Text(
                    "设置",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomSelectionOverlay extends StatelessWidget {
  const _CustomSelectionOverlay();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
      ),
    );
  }
}
