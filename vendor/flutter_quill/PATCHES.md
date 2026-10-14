# flutter_quill 11.6.0 本地补丁

来源：flutter_quill 11.6.0，保留原 MIT LICENSE；仅包含运行所需源码。

- `heading_spacing.dart`：首行标题不加上间距；非首行一级标题始终使用配置间距，二、三级标题仅正文之后增加间距。
- `raw_editor_state.dart`、`text_block.dart`：普通标题和块内标题共用以上间距规则，不向用户文档插入空行或额外格式。
- `text_line.dart`：有序／无序列表标记按实际正文首行基线定位，避免中文字体回退或行内字号变化造成偏移。

- `raw_editor_state.dart`、`raw_editor_state_text_input_client_mixin.dart`：仅正文自身主焦点维持光标和输入连接；失去焦点不重新请求键盘，忽略过期 IME 消息。
- `editor_keyboard_shortcuts.dart`：正文失去主焦点时停用文档级快捷操作，防止表格 TextField 继承删除／选择覆盖导致单元格混入整篇文档。

- `quill_controller.dart`：清理图片缓存不再清空系统文本剪贴板，避免与刚完成的文本复制竞争。

升级上游版本时需保留或重新验证这些差异；回归测试位于主项目 `test/journal_v32_test.dart` 、`test/journal_v33_test.dart` 、`test/journal_v34_test.dart` 、`test/journal_v341_test.dart` 和 `test/journal_v350_test.dart`。
