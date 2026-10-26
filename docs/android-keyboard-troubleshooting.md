# Android 键盘不可见排查记录

首次记录：2026-10-26，3.13.5 调试构建 75／76。

## 本次现象与结论

点击笔记正文后光标出现，键盘不可见；输入英文时只出现候选条。记录搜索框也出现同类现象。修改应用焦点处理后，在构建 76 中仍能复现，不能将这些代码修改宣称为本次故障的根因修复。

已证实故障涉及 Android 与微信输入法的输入链路状态：原输入法 `com.tencent.wetype/.plugin.hld.WxHldService` 重启后，同一构建、同一输入位置恢复完整屏幕键盘，正文和标题均可重新进入编辑。处理未切换到其他输入法，也未清除输入法或应用数据。

排查中发现已连接的 `Xiaomi Smart Band 10 Pro 3833` 被 Android 输入系统列为外部 `KEYBOARD | DPAD`，`KeyboardType: 2`；系统 `show_ime_with_hard_keyboard` 原值为 `0`。本次将其设为 `1` 并重启原输入法后恢复。不过，后续对照中把该值切回 `0` 并重启输入法，未稳定复现故障。因此外设键盘分类和该选项只是相关条件，不能据此断言“手环／关闭该选项必然导致故障”。输入法内部进入异常候选模式的具体触发条件尚未确定。

最终保留 `show_ime_with_hard_keyboard=1`，当前输入法保持微信输入法。该值属于手机系统设置，不属于应用设置备份。

## 区分三类问题

| 检查结果 | 排查方向 |
| --- | --- |
| 点击后无光标、焦点未进入编辑器 | 命中区域、FocusNode、路由恢复、选框／表格拦截 |
| 有光标，未连接输入法或未请求显示 | TextInput 客户端、requestKeyboard、ignoreFocusOnTextChange、skipRequestKeyboard |
| 有光标，输入法已启动，但只有候选条或键盘窗口不可见 | 输入法状态、外接设备键盘分类、系统屏幕键盘选项 |

`mInputShown=true`、`mIsInputViewShown=true` 或测试环境中的 `TextInput.show` 只能证明部分链路，不能证明手机上出现了完整键盘。本次这些值曾为 true，但截图仍只有候选条。应同时查看实际截图和 IME 窗口占据的区域。

## 下次排查步骤

1. 保存当前内容，记录应用版本、输入法、具体输入位置及复现步骤；先比较正文、标题、搜索和普通弹窗，确认影响范围。
2. 查询当前输入法、屏幕键盘选项和外部键盘分类：

   ```powershell
   adb shell settings get secure default_input_method
   adb shell settings get secure --user current show_ime_with_hard_keyboard
   adb shell dumpsys input
   adb shell dumpsys input_method
   adb shell dumpsys window
   ```

3. 若有光标而仅显示候选条，先提交或取消当前候选，再重启当前输入法；必要时在系统实体键盘设置中开启屏幕键盘。本次恢复使用：

   ```powershell
   adb shell settings put secure --user current show_ime_with_hard_keyboard 1
   adb shell am force-stop com.tencent.wetype
   adb shell ime set com.tencent.wetype/.plugin.hld.WxHldService
   ```

4. 回到原输入位置重新点击，核对完整键盘、光标、实际输入及删除；再检查关闭弹窗、执行快捷操作和返回前台后重新编辑。记录对照结果，未稳定复现的推测保留为待确认条件。

## 应用层保留的处理

浏览操作清除当前焦点并抑制程序通知自动请求键盘；显式点击正文时恢复输入连接并重新请求键盘，不长期禁止正文 FocusNode 获取焦点。该处理覆盖应用自己的焦点恢复路径，不能绕过 Android 或输入法的显示策略。

自动检查见 `test/journal_v3135_test.dart`、`test/journal_v3132_test.dart` 中相应键盘用例，以及 `test/keyboard_locations_v3135_test.dart`。后者逐项检查标题、标签、搜索、合集名称、表格行列数和单元格、待办新增／编辑／改名、时历名称及日期时间输入；真机键盘状态还需单独验证。
