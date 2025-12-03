# inch-light
一个简单的记事本和多任务计时器



## 待新增功能

- [ ] 新增【设置】模块，可开关以下选项：每日0点重置计时、

- [ ] 记录每日各项专注时长，提供数据可视化模块，可以选择周视图/月视图/年视图看到统计每日专注时长的比例条形图和折线图

- [ ] 可新增桌面组件，专注一个，清单一个
- [ ] 把倒计时结束的提示音改为[千早爱音糖笑5分钟纯享音频](https://www.bilibili.com/video/BV1FgL9zgEQJ)，并且无法关闭必须放完

 `PS：学业繁重，不一定会继续更新，真有需求的同志自己写代码吧`





```
Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    void safeLoad(
      String key,
      List<dynamic> list,
      Function(Map<String, dynamic>) factory,
    ) {
      String? jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(jsonStr) as List;
          list.clear();
          for (var item in decoded) {
            try {
              list.add(factory(item));
            } catch (e) {
              debugPrint("跳过损坏数据: $e");
            }
          }
        } catch (e) {
          debugPrint("加载 $key 失败: $e");
        }
      }
    }

    safeLoad('timerTasks', _timerTasks, (e) => TaskItem.fromJson(e));
    safeLoad('dailyTasks', _dailyTasks, (e) => TaskItem.fromJson(e));
    safeLoad('normalTasks', _normalTasks, (e) => TaskItem.fromJson(e));
    safeLoad('cycleTasks', _cycleTasks, (e) => CycleTask.fromJson(e));

    _checkDailyReset(prefs); // 检查是否跨天
    _recalcAllCycles();
  }
```

