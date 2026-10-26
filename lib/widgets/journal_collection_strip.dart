import 'package:flutter/material.dart';

/// A deliberate pull beyond the first collection opens the collection list.
class JournalCollectionStrip extends StatefulWidget {
  const JournalCollectionStrip({
    super.key,
    required this.children,
    required this.onOpenCollections,
  });

  final List<Widget> children;
  final VoidCallback onOpenCollections;

  @override
  State<JournalCollectionStrip> createState() => _JournalCollectionStripState();
}

class _JournalCollectionStripState extends State<JournalCollectionStrip> {
  final _scroll = ScrollController();
  int? _pointer;
  double _pullDistance = 0;
  double _startOffset = 0;
  Offset _travel = Offset.zero;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      // Count finger travel directly: a fast drag can release before the
      // ScrollPosition has painted its overscroll displacement.
      _pointer = _pointer == null ? event.pointer : -1;
      _startOffset = _scroll.hasClients
          ? (_scroll.offset - _scroll.position.minScrollExtent).clamp(
              0.0,
              double.infinity,
            )
          : 0;
      _travel = Offset.zero;
      _pullDistance = 0;
    },
    onPointerMove: (event) {
      if (_pointer != event.pointer || !_scroll.hasClients) return;
      _travel += event.delta;
      _pullDistance = (_travel.dx - _startOffset).clamp(0.0, double.infinity);
    },
    onPointerCancel: (_) {
      _pointer = null;
      _pullDistance = 0;
    },
    onPointerUp: (event) {
      final deliberatePull =
          _pointer == event.pointer &&
          _pullDistance >= 220 &&
          _scroll.hasClients &&
          _travel.dx > _travel.dy.abs() * 1.3;
      _pointer = null;
      if (deliberatePull) widget.onOpenCollections();
    },
    child: SingleChildScrollView(
      key: const ValueKey('collection-tabs'),
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const _CollectionPullPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: widget.children),
    ),
  );
}

class _CollectionPullPhysics extends BouncingScrollPhysics {
  const _CollectionPullPhysics({super.parent});

  @override
  _CollectionPullPhysics applyTo(ScrollPhysics? ancestor) =>
      _CollectionPullPhysics(parent: buildParent(ancestor));

  // About 250 logical pixels of extra finger travel is needed to reach 64px.
  // Resistance grows with distance; the native spring returns the strip on release.
  @override
  double frictionFactor(double overscrollFraction) =>
      .26 * (1 - overscrollFraction) * (1 - overscrollFraction);
}
