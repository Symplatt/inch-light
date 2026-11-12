import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';
import '../models/meal_menu.dart';
import '../providers/app_provider.dart';
import '../widgets/app_dialog.dart';
import '../widgets/swipe_delete_card.dart';

class MealPage extends StatefulWidget {
  const MealPage({super.key, required this.onBack});
  final VoidCallback onBack;
  @override
  State<MealPage> createState() => _MealPageState();
}

class _MealPageState extends State<MealPage> {
  String? _eating;
  final _random = Random();
  Future<bool> _update(MealData Function(MealData) change) async {
    try {
      await context.read<AppProvider>().updateMeals(change);
      return true;
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      return false;
    }
  }

  Future<void> _eat(String menuId, String dishId) async {
    if (_eating != null) return;
    setState(() => _eating = dishId);
    await _update((data) {
      final menu = data.menus.firstWhere((m) => m.id == menuId);
      // Preserve each meal's timestamp; today's latest tap sorts after earlier meals.
      return data.replace(
        menu.withDishes(
          menu.dishes
              .map((d) => d.id == dishId ? d.eat(DateTime.now()) : d)
              .toList(),
        ),
      );
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _eating = null);
  }

  void _add({required bool menu}) {
    final menuId = context.read<AppProvider>().meals.selected.id;
    showDialog<void>(
      context: context,
      builder: (_) => _MealNameDialog(
        title: menu ? '新增菜单' : '新增菜品',
        save: (name) => context.read<AppProvider>().updateMeals((data) {
          if (menu) {
            if (data.menus.any((m) => m.name == name))
              throw StateError('菜单名称已存在');
            final item = MealMenu(id: const Uuid().v4(), name: name);
            return MealData(menus: [...data.menus, item], selectedId: item.id);
          }
          final current = data.menus.firstWhere((m) => m.id == menuId);
          if (current.dishes.any((d) => d.name == name))
            throw StateError('菜品名称已存在');
          return data.replace(
            current.withDishes([
              ...current.dishes,
              MealDish(id: const Uuid().v4(), name: name),
            ]),
          );
        }),
      ),
    );
  }

  Future<void> _menus() async {
    final data = context.read<AppProvider>().meals;
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('切换菜单'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final menu in data.menus)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(menu.name),
                  trailing: menu.id == data.selected.id
                      ? const Icon(Icons.check, size: 20)
                      : null,
                  onTap: () => Navigator.pop(ctx, menu.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (id != null && mounted)
      await _update((d) => MealData(menus: d.menus, selectedId: id));
  }

  Future<void> _pick() async {
    final menu = context.read<AppProvider>().meals.selected;
    if (menu.dishes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先新增菜品')));
      return;
    }
    var dish = menu.pickDish(_random);
    final eat = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, updateDialog) => AppDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          constraints: const BoxConstraints(maxWidth: 360),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: SizedBox(
            width: 336,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '随机选菜',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textGrey,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 32),
                    child: Text(
                      dish.name,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  OverflowBar(
                    alignment: MainAxisAlignment.spaceBetween,
                    overflowAlignment: OverflowBarAlignment.end,
                    spacing: 12,
                    overflowSpacing: 8,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: EdgeInsets.zero,
                          foregroundColor: AppColors.textGrey,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onPressed: () => updateDialog(() {
                          final alternatives = menu.dishes
                              .where((d) => d.id != dish.id)
                              .toList();
                          if (alternatives.isNotEmpty) {
                            dish = menu
                                .withDishes(alternatives)
                                .pickDish(_random);
                          }
                        }),
                        child: const Text('再换一道'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: EdgeInsets.zero,
                          foregroundColor: AppColors.textGrey,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('不想吃了'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: EdgeInsets.zero,
                          foregroundColor: AppColors.textGrey,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('就决定是你了'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (eat == true && mounted) await _eat(menu.id, dish.id);
  }

  void _edit(MealMenu menu, MealDish dish) {
    showDialog<void>(
      context: context,
      builder: (_) => _MealNameDialog(
        title: '编辑菜品',
        initial: dish.name,
        save: (name) => context.read<AppProvider>().updateMeals((data) {
          final current = data.menus.firstWhere((m) => m.id == menu.id);
          if (current.dishes.any((d) => d.id != dish.id && d.name == name)) {
            throw StateError('菜品名称已存在');
          }
          return data.replace(
            current.withDishes(
              current.dishes
                  .map(
                    (d) => d.id == dish.id
                        ? MealDish(id: d.id, name: name, eaten: d.eaten)
                        : d,
                  )
                  .toList(),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _delete(MealMenu menu, MealDish dish) async {
    final saved = await _update((data) {
      final current = data.menus.firstWhere((m) => m.id == menu.id);
      return data.replace(
        current.withDishes(
          current.dishes.where((d) => d.id != dish.id).toList(),
        ),
      );
    });
    if (!saved) throw StateError('菜品删除失败');
  }

  void _history(MealMenu menu, MealDish dish) {
    var swipeDistance = 0.0;
    var deleting = false;
    showDialog<void>(
      context: context,
      builder: (ctx) => GestureDetector(
        onLongPress: () {
          Navigator.pop(ctx);
          _edit(menu, dish);
        },
        onHorizontalDragStart: (_) => swipeDistance = 0,
        onHorizontalDragUpdate: (details) => swipeDistance += details.delta.dx,
        onHorizontalDragEnd: (details) async {
          if (deleting ||
              (swipeDistance > -72 && (details.primaryVelocity ?? 0) >= -250))
            return;
          deleting = true;
          // The same left-swipe action is available on the dish card and viewer.
          try {
            await _delete(menu, dish);
            if (ctx.mounted) Navigator.pop(ctx);
          } catch (_) {
            deleting = false;
          }
        },
        child: AppAlertDialog(
          title: Text(dish.name),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (dish.eaten.isEmpty) const Text('暂无食用记录'),
                for (final date in dish.eaten.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(_date(date, time: true)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialog) => AppAlertDialog(
                    title: const Text('删除菜品？'),
                    content: const Text('同时删除这道菜的食用记录。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  try {
                    await _delete(menu, dish);
                  } catch (_) {}
                }
              },
              child: const Text('删除菜品'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<AppProvider>().meals.selected;
    Widget action(String label, IconData icon, VoidCallback callback) =>
        SizedBox(
          width: 40,
          child: IconButton(
            tooltip: label,
            onPressed: _eating == null ? callback : null,
            icon: Icon(icon),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: OutlinedButton(
          onPressed: _menus,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textDark,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: Color(0xFFE7E8EB)),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  menu.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 18),
            ],
          ),
        ),
        actions: [
          action('随机选菜', Icons.casino_outlined, _pick),
          action('新增菜单', Icons.playlist_add, () => _add(menu: true)),
          action('新增菜品', Icons.add, () => _add(menu: false)),
          SizedBox(
            width:
                8 +
                (MediaQuery.sizeOf(context).width - 720).clamp(
                      0.0,
                      double.infinity,
                    ) /
                    2,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: menu.dishes.isEmpty
              ? const Center(
                  child: Text(
                    '暂无菜品',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                )
              : _DishList(
                  key: ValueKey(menu.id),
                  dishes: menu.sortedDishes,
                  onEat: _eating == null
                      ? (dish) => _eat(menu.id, dish.id)
                      : null,
                  onHistory: (dish) => _history(menu, dish),
                  onEdit: (dish) => _edit(menu, dish),
                  onDelete: (dish) => _delete(menu, dish),
                ),
        ),
      ),
    );
  }
}

String _date(DateTime date, {bool time = false}) {
  final local = date.toLocal();
  final day =
      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  return time
      ? '$day ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}'
      : day;
}

class _DishList extends StatefulWidget {
  const _DishList({
    super.key,
    required this.dishes,
    required this.onEat,
    required this.onHistory,
    required this.onEdit,
    required this.onDelete,
  });
  final List<MealDish> dishes;
  final ValueChanged<MealDish>? onEat;
  final ValueChanged<MealDish> onHistory;
  final ValueChanged<MealDish> onEdit;
  final Future<void> Function(MealDish) onDelete;
  @override
  State<_DishList> createState() => _DishListState();
}

class _DishListState extends State<_DishList> {
  final _key = GlobalKey<AnimatedListState>();
  late final _items = [...widget.dishes];
  static const _duration = Duration(milliseconds: 260);
  @override
  void didUpdateWidget(covariant _DishList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Remove moved/removed rows first, then insert at their new sorted position.
    final target = widget.dishes;
    for (var i = _items.length - 1; i >= 0; i--) {
      final index = target.indexWhere((d) => d.id == _items[i].id);
      if (index < 0 || target[index].lastEaten != _items[i].lastEaten) {
        final removed = _items.removeAt(i);
        _key.currentState!.removeItem(
          i,
          (_, animation) =>
              _card(removed, animation, removing: true, number: i + 1),
          duration: _duration,
        );
      }
    }
    for (var i = 0; i < target.length; i++) {
      if (i >= _items.length || _items[i].id != target[i].id) {
        _items.insert(i, target[i]);
        _key.currentState!.insertItem(i, duration: _duration);
      } else {
        _items[i] = target[i];
      }
    }
  }

  Widget _card(
    MealDish dish,
    Animation<double> animation, {
    bool removing = false,
    required int number,
  }) => SizeTransition(
    sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
    child: FadeTransition(
      opacity: animation,
      child: SwipeDeleteCard(
        id: dish.id,
        enabled: !removing,
        bottomMargin: 6,
        onDeleted: () => widget.onDelete(dish),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E8EB)),
          ),
          child: ListTile(
            leading: Container(
              width: max(
                32,
                MediaQuery.textScalerOf(context).scale(16) *
                    ('$number'.length * 0.65 + 0.8),
              ),
              height: max(
                32,
                MediaQuery.textScalerOf(context).scale(16) *
                    ('$number'.length * 0.65 + 0.8),
              ),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F1F3),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            minLeadingWidth: 24,
            horizontalTitleGap: 12,
            minTileHeight: 64,
            minVerticalPadding: 6,
            contentPadding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            title: Text(
              dish.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                dish.eaten.isEmpty
                    ? '还没吃过'
                    : '上次 ${_date(dish.lastEaten!)} · 共 ${dish.eaten.length} 次',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ),
            onTap: removing ? null : () => widget.onHistory(dish),
            onLongPress: removing ? null : () => widget.onEdit(dish),
            trailing: IconButton(
              tooltip: '今天吃了${dish.name}',
              style: IconButton.styleFrom(
                fixedSize: const Size(48, 48),
                foregroundColor: AppColors.textGrey,
                side: const BorderSide(color: Color(0xFFD8DBE1)),
                shape: const CircleBorder(),
              ),
              icon: Builder(
                builder: (context) => CustomPaint(
                  size: const Size.square(22),
                  painter: _MealBowlPainter(
                    color: IconTheme.of(context).color ?? AppColors.textGrey,
                  ),
                ),
              ),
              onPressed: removing || widget.onEat == null
                  ? null
                  : () => widget.onEat!(dish),
            ),
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedList(
    key: _key,
    initialItemCount: _items.length,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    itemBuilder: (_, index, animation) =>
        _card(_items[index], animation, number: index + 1),
  );
}

class _MealNameDialog extends StatefulWidget {
  const _MealNameDialog({
    required this.title,
    required this.save,
    this.initial = '',
  });
  final String title;
  final String initial;
  final Future<void> Function(String) save;
  @override
  State<_MealNameDialog> createState() => _MealNameDialogState();
}

class _MealNameDialogState extends State<_MealNameDialog> {
  late final _text = TextEditingController(text: widget.initial);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_text.text.trim().isEmpty) {
      setState(() => _error = '请输入名称');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.save(_text.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = e is StateError ? e.message.toString() : '保存失败，请重试';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppAlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: _text,
          autofocus: true,
          enabled: !_saving,
          maxLength: 80,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(hintText: '名称', errorText: _error),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _saving ? null : _save, child: const Text('保存')),
      ],
    ),
  );
}

// 用归一化路径保持参考图中碗口、碗足与两根筷子的比例。
class _MealBowlPainter extends CustomPainter {
  const _MealBowlPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final ink = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(const Offset(12.7, 12), const Offset(18.7, 2.1), ink);
    canvas.drawLine(const Offset(16.1, 12), const Offset(22.1, 4.8), ink);
    final bowl = Path()
      ..moveTo(1.1, 12.3)
      ..lineTo(21.8, 12.3)
      ..cubicTo(21.5, 18.3, 17.4, 22.6, 11.5, 22.6)
      ..cubicTo(5.5, 22.6, 1.4, 18.3, 1.1, 12.3)
      ..close();
    canvas.drawPath(bowl, ink);
    final foot = Path()
      ..moveTo(7.4, 22.3)
      ..lineTo(7.3, 23)
      ..quadraticBezierTo(11.5, 22, 15.7, 23)
      ..lineTo(15.6, 22.3);
    canvas.drawPath(foot, ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MealBowlPainter oldDelegate) => color != oldDelegate.color;
}
