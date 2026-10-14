# 一日千录 · inch-light

轻量的 Flutter 待办、记录与时历应用。当前版本：**3.5.0**。

## 下载

从 [GitHub Releases](https://github.com/Symplatt/inch-light/releases/latest) 下载 Android 安装包。普通 Android 手机优先选择 `app-arm64-v8a-release.apk`，其他设备按处理器架构选择对应文件。

## 使用

记录支持富文本、Markdown 表格粘贴、合集记忆及右滑多选；多选时系统返回先退出选择。笔记左滑删除与待办使用相同手势和动画，删除后一分钟内可恢复。表头悬浮菜单可复制或删除表格，表格下两次退格也可删除整表；不支持双击删行和选框列表。

时历剩余 24 小时内显示红点，倒计时归零立即删除，周期继续推进。设置页直接提供剪贴板与文件导入；数据导出自动复制并保存到授权的 `/storage/emulated/0/inch-light/`，首次选择文件夹后无需重复确认，本应用导出超过 7 天的备份自动清理。

完整更新见 [CHANGELOG](CHANGELOG.md)；兼容性说明见 [版本说明](docs/一日千录更新说明.md)。

## 项目结构

```text
lib/
  constants/   颜色和视觉常量
  models/      事项、笔记、合集和时历数据模型
  providers/   状态管理、本地持久化和数据导入导出
  screens/     待办、记录编辑、时历、设置与导航
  utils/       截止时间、周期计算和 Markdown 导出
  widgets/     共用控件
vendor/flutter_quill/  固定 11.6.0 的本地源码与标题间距、列表对齐补丁（保留 MIT LICENSE）
assets/        图标
test/          数据与界面回归测试
```

## 发布

从 `2.0.1` 开始重新计算版本。后续修改按语义化版本递增，日常修复默认递增补丁号；`pubspec.yaml` 的构建号始终递增。

每次发布同步更新 [CHANGELOG](CHANGELOG.md)、版本号和受影响的 README 内容，通过格式检查、静态分析与测试后推送代码和 `vX.Y.Z` 标签。GitHub Release 使用 CHANGELOG 对应版本内容，并附上 Android APK。

当前 Android 工程沿用开发签名，仅适用于自行安装；正式商店分发需要单独配置发布签名。不同签名的安装包无法直接覆盖安装，请先备份数据。
