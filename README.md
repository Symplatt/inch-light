# 一日千录 · inch-light

轻量的 Flutter 待办与时历应用。当前版本：**2.1.1**。

## 下载

从 [GitHub Releases](https://github.com/Symplatt/inch-light/releases/latest) 下载 Android 安装包。普通 Android 手机优先选择 `app-arm64-v8a-release.apk`，其他设备按处理器架构选择对应文件。

## 功能

- **待办**：普通事项、每日打卡、合集、标签、截止时间（支持一键「今日截止」「明日截止」至对应日期 23:59）、置顶与置底、完成状态及批量操作；合集使用整张卡片，内部事项以浅灰细线分隔。
- **时历**：重要日期倒计时，以及每日、每周、每月、每年的周期事项；支持全天事项，两类列表可独立折叠，卡片支持左右滑动删除和长按编辑。卡片左侧显示名称与日期，右侧显示三列倒计时，数字在上、单位在下，以细竖线分隔；剩余时间达到 24 小时显示年、月、日，不足 24 小时显示时、分、秒。
- **时间选择**：待办与时历共用日历日期选择和 24 小时数字时间输入。
- **本地数据**：自动保存；设置中可通过剪贴板导出和导入 JSON 备份。导入会覆盖备份中包含的对应数据区段，请先导出备份。

长按事项直接编辑，编辑标题右侧可置顶、置底或取消对应排序；长按合集打开操作菜单。删除合集会同时删除其中已完成和未完成的事项；批量删除合集同样适用。已完成事项在完成 24 小时后自动清理，每日打卡在日期变化时重置。

专注和记录模块已移除。旧版本设备上的记录数据不会主动清除，但当前版本不再展示、编辑或导出该数据；需要留存时请在升级前用旧版本导出。

## 平台支持

项目包含 Android、iOS、Windows、macOS、Linux 和 Web 工程。时历仅在应用内展示时间，不发送到期通知，不申请通知或精确闹钟权限。升级后首次打开会清理旧版时历提醒。

月末周期遇到较短月份时取当月最后一天，随后恢复原始日期；2 月 29 日的年度事项在平年使用 2 月 28 日。

## 本地开发

使用 Flutter **3.38.5**（Dart 3.10）或兼容版本。Android 构建需要 JDK 17 与 Android SDK 36。

```sh
flutter pub get
flutter run
```

验证与构建：

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

更新图标后生成各平台启动图标：

```sh
dart run flutter_launcher_icons
```

## 项目结构

```text
lib/
  constants/   颜色和视觉常量
  models/      事项、合集和时历数据模型
  providers/   状态管理、本地持久化和数据导入导出
  screens/     待办、时历与导航
  utils/       截止时间和周期计算
  widgets/     共用控件
assets/        图标
test/          数据与界面回归测试
```

## 发布

从 `2.0.1` 开始重新计算版本。后续修改按语义化版本递增，日常修复默认递增补丁号；`pubspec.yaml` 的构建号始终递增。

每次发布同步更新 [CHANGELOG](CHANGELOG.md)、版本号和受影响的 README 内容，通过格式检查、静态分析与测试后推送代码和 `vX.Y.Z` 标签。GitHub Release 使用 CHANGELOG 对应版本内容，并附上 Android APK。

当前 Android 工程沿用开发签名，仅适用于自行安装；正式商店分发需要单独配置发布签名。不同签名的安装包无法直接覆盖安装，请先备份数据。
