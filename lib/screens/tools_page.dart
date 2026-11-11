import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

import '../constants/app_colors.dart';
import '../utils/journal_sort.dart';
import '../widgets/tool_icon.dart';
import 'work_log_page.dart';
import 'meal_page.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({
    super.key,
    this.active = true,
    this.openLastRequest = 0,
    this.openLastOnEntry = false,
  });
  final bool active;
  final int openLastRequest;
  final bool openLastOnEntry;

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  String? _selectedTool;

  void _restoreTool() {
    final provider = context.read<AppProvider>();
    _selectedTool =
        (widget.openLastOnEntry || provider.autoOpenLastTool) &&
            _tools.any((tool) => tool.id == provider.lastTool)
        ? provider.lastTool
        : null;
  }

  @override
  void initState() {
    super.initState();
    _restoreTool();
  }

  @override
  void didUpdateWidget(covariant ToolsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openLastRequest != oldWidget.openLastRequest) {
      final last = context.read<AppProvider>().lastTool;
      _selectedTool = _tools.any((tool) => tool.id == last) ? last : null;
    } else if (widget.active && !oldWidget.active) {
      _restoreTool();
    }
  }

  static final _tools = [
    (id: 'meals', name: '吃什么'),
    (id: 'work_log', name: '工作日志'),
  ]..sort((a, b) => JournalNameKey(a.name).compareTo(JournalNameKey(b.name)));

  void _openTool(String id) {
    context.read<AppProvider>().setLastTool(id);
    setState(() => _selectedTool = id);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.active && _selectedTool != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) setState(() => _selectedTool = null);
        },
        child: _selectedTool == 'meals'
            ? MealPage(onBack: () => setState(() => _selectedTool = null))
            : WorkLogPage(onBack: () => setState(() => _selectedTool = null)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('工具')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE7E8EB)),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisExtent: 104,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _tools.length,
                  itemBuilder: (context, index) {
                    final tool = _tools[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openTool(tool.id),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE7E8EB),
                              ),
                            ),
                            child: ToolIcon(meal: tool.id == 'meals'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tool.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
