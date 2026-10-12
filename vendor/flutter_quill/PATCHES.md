# flutter_quill 11.6.0 本地补丁

来源：flutter_quill 11.6.0，保留原 MIT LICENSE；仅包含运行所需源码。

- `heading_spacing.dart`：标题在文首或紧接另一标题时不加上间距，接在正文后使用配置的上间距。
- `raw_editor_state.dart`、`text_block.dart`：普通标题和块内标题共用以上间距规则，不向用户文档插入空行或额外格式。

升级上游版本时需保留或重新验证这些差异；回归测试位于主项目 `test/journal_v32_test.dart`。
