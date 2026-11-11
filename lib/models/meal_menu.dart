import 'dart:math';

class MealDish {
  MealDish({
    required this.id,
    required this.name,
    List<DateTime> eaten = const [],
  }) : eaten = List.unmodifiable(eaten);
  final String id;
  final String name;
  final List<DateTime> eaten;
  DateTime? get lastEaten => eaten.isEmpty ? null : eaten.last;
  MealDish eat(DateTime time) =>
      MealDish(id: id, name: name, eaten: [...eaten, time]);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'eaten': eaten.map((d) => d.toIso8601String()).toList(),
  };
  factory MealDish.fromJson(Map<String, dynamic> json) {
    final dates =
        (json['eaten'] as List).map((d) => DateTime.parse(d as String)).toList()
          ..sort();
    return MealDish(
      id: json['id'] as String,
      name: json['name'] as String,
      eaten: dates,
    );
  }
}

class MealMenu {
  MealMenu({
    required this.id,
    required this.name,
    List<MealDish> dishes = const [],
  }) : dishes = List.unmodifiable(dishes);
  final String id;
  final String name;
  final List<MealDish> dishes;
  MealMenu withDishes(List<MealDish> value) =>
      MealMenu(id: id, name: name, dishes: value);

  MealDish pickDish(Random random, {DateTime? now}) {
    if (dishes.isEmpty) throw StateError('请先新增菜品');
    final today = now ?? DateTime.now();
    // UTC calendar dates keep daylight-saving changes out of the day count.
    final day = DateTime.utc(today.year, today.month, today.day);
    final days = dishes.map((dish) {
      final last = dish.lastEaten?.toLocal();
      return last == null
          ? 1
          : max(
              0,
              day
                  .difference(DateTime.utc(last.year, last.month, last.day))
                  .inDays,
            );
    }).toList();
    final largest = days.reduce(max);
    // Subtracting the maximum preserves softmax while avoiding exp overflow.
    final weights = days.map((days) => exp(days - largest)).toList();
    var remaining = random.nextDouble() * weights.reduce((a, b) => a + b);
    for (var i = 0; i < dishes.length; i++) {
      remaining -= weights[i];
      if (remaining < 0) return dishes[i];
    }
    return dishes.last;
  }

  List<MealDish> get sortedDishes => [...dishes]
    ..sort((a, b) {
      final order = a.lastEaten == null
          ? (b.lastEaten == null ? 0 : -1)
          : b.lastEaten == null
          ? 1
          : a.lastEaten!.compareTo(b.lastEaten!);
      return order == 0
          ? dishes.indexOf(a).compareTo(dishes.indexOf(b))
          : order;
    });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dishes': dishes.map((d) => d.toJson()).toList(),
  };
  factory MealMenu.fromJson(Map<String, dynamic> json) => MealMenu(
    id: json['id'] as String,
    name: json['name'] as String,
    dishes: (json['dishes'] as List)
        .map((d) => MealDish.fromJson(Map<String, dynamic>.from(d)))
        .toList(),
  );
}

class MealData {
  MealData({required List<MealMenu> menus, this.selectedId = 'default'})
    : menus = List.unmodifiable(menus);
  factory MealData.empty() => MealData(
    menus: [MealMenu(id: 'default', name: '默认菜单')],
  );
  final List<MealMenu> menus;
  final String selectedId;
  MealMenu get selected =>
      menus.firstWhere((m) => m.id == selectedId, orElse: () => menus.first);
  MealData replace(MealMenu menu) => MealData(
    menus: menus.map((m) => m.id == menu.id ? menu : m).toList(),
    selectedId: selectedId,
  );
  Map<String, dynamic> toJson() => {
    'menus': menus.map((m) => m.toJson()).toList(),
    'selectedId': selectedId,
  };
  factory MealData.fromJson(Map<String, dynamic> json) {
    final menus = (json['menus'] as List)
        .map((m) => MealMenu.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    if (menus.isEmpty ||
        menus.map((m) => m.id).toSet().length != menus.length ||
        menus.any(
          (m) =>
              m.id.isEmpty ||
              m.name.trim().isEmpty ||
              m.dishes.map((d) => d.id).toSet().length != m.dishes.length ||
              m.dishes.any((d) => d.id.isEmpty || d.name.trim().isEmpty),
        )) {
      throw const FormatException('Invalid meal menus');
    }
    return MealData(
      menus: menus,
      selectedId: json['selectedId'] as String? ?? menus.first.id,
    );
  }
}
