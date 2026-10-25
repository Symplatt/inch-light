# flutter_quill 11.6.0 本地补丁

来源：flutter_quill 11.6.0，保留原 MIT LICENSE；仅包含运行所需源码。

- `text_line.dart`、`proxy.dart`、`inline_code_padding.dart`：行内代码两侧分别预留 7 逻辑像素内边距与 3 逻辑像素外间隔，底色只绘制在实际占位范围内；布局占位与文档偏移双向映射，正文、复制内容和输入法文本不增加空格，连续代码跨富文本片段共用两侧间距。

- `heading_spacing.dart`：首行标题不加上间距；非首行一级标题始终使用配置间距，二、三级标题仅正文之后增加间距。
- `raw_editor_state.dart`、`text_block.dart`：普通标题和块内标题共用以上间距规则，不向用户文档插入空行或额外格式。
- `text_line.dart`：有序／无序列表标记按实际正文首行基线定位，避免中文字体回退或行内字号变化造成偏移。

- `raw_editor_state.dart`、`raw_editor_state_text_input_client_mixin.dart`：仅正文自身主焦点维持光标和输入连接；失去焦点不重新请求键盘，忽略过期 IME 消息。
- `editor_keyboard_shortcuts.dart`：正文失去主焦点时停用文档级快捷操作，防止表格 TextField 继承删除／选择覆盖导致单元格混入整篇文档。

- `quill_controller.dart`：清理图片缓存不再清空系统文本剪贴板，避免与刚完成的文本复制竞争。

升级上游版本时需保留或重新验证这些差异；回归测试位于主项目 `test/journal_v32_test.dart` 、`test/journal_v33_test.dart` 、`test/journal_v34_test.dart` 、`test/journal_v341_test.dart` 和 `test/journal_v350_test.dart`。

- `text_line.dart`：未指定对齐的正文与列表折行使用两端对齐，消除右侧不足一个字宽的额外空隙；标题、代码和显式对齐保持原样，不改文档数据。

- `document.dart`：每次成功 compose 同步递增只读 revision，供编辑页缓存正文序列化与字数；光标、焦点和输入法组合范围改变不递增，不写入 Delta 或备份。避免使用异步 changes 通知时尚未失效的缓存。

- `text_line.dart`：行首行内代码保留 7 逻辑像素内部占位，不加外间隔，灰底矩形与正文左边缘对齐；移除灰底向下 1 像素的偏移。复选框列表正文上移 2 逻辑像素，光标、选区与命中坐标共用正文偏移。

- `raw_editor_state.dart`：选框切换与选区恢复共用忽略焦点更新的状态，结束后还原控制器标志；应用选框不接收焦点，保留点击前的输入连接和键盘状态。

- `text_line.dart`：列表标记使用约束测量基线，避免列表区块拆分重排时读取尚未完成布局的标记子节点。

- `raw_editor_state.dart`：相邻选框区块无论勾选状态均使用列表项间距，避免勾选导致区块拆分后额外增加段间距；列表首尾与正文的间距保持原配置。

- `text_line.dart`：列表行按固定字体支撑高度排版，避免纯中文末尾追加英文触发字体回退后整行下移；采用该行最大显式字号，保留大字号文字的空间，非列表正文保持原样。
