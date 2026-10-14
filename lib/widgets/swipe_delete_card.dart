import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Paint under the entire rounded card, including the moving edge's corners.
class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key, this.fromLeft = false});
  final bool fromLeft;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.danger,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
    ),
  );
}

class SwipeDeleteCard extends StatefulWidget {
  const SwipeDeleteCard({
    super.key,
    required this.id,
    required this.child,
    required this.onDeleted,
    this.enabled = true,
    this.radius = 16,
    this.bottomMargin = 12,
    this.direction = DismissDirection.endToStart,
  });
  final String id;
  final bool enabled;
  final Widget child;
  final FutureOr<void> Function() onDeleted;
  final double radius;
  final double bottomMargin;
  final DismissDirection direction;
  @override
  State<SwipeDeleteCard> createState() => _SwipeDeleteCardState();
}

class _SwipeDeleteCardState extends State<SwipeDeleteCard> {
  bool _moving = false;
  bool _fromLeft = false;
  bool _dismissed = false;
  int _attempt = 0;
  Future<void> _delete() async {
    setState(() => _dismissed = true);
    try {
      await widget.onDeleted();
    } catch (_) {
      // A failed persistence operation restores a fresh swipe state, rather
      // than leaving a dismissed widget in the tree or hiding a restored item.
      if (mounted) {
        setState(() {
          _dismissed = false;
          _moving = false;
          _attempt++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _dismissed
      ? const SizedBox.shrink()
      : Padding(
          padding: EdgeInsets.only(bottom: widget.bottomMargin),
          child: ClipRRect(
            // Corner badges may extend over the outline while the card rests.
            clipBehavior: _moving ? Clip.antiAlias : Clip.none,
            borderRadius: BorderRadius.circular(widget.radius),
            child: Stack(
              children: [
                if (_moving)
                  Positioned.fill(
                    child: SwipeDeleteBackground(fromLeft: _fromLeft),
                  ),
                Dismissible(
                  key: ValueKey('${widget.id}:$_attempt'),
                  direction: widget.enabled
                      ? widget.direction
                      : DismissDirection.none,
                  onUpdate: (details) {
                    final moving = details.progress > 0;
                    final fromLeft =
                        (details.direction == DismissDirection.startToEnd) ==
                        (Directionality.of(context) == TextDirection.ltr);
                    if (_moving != moving || _fromLeft != fromLeft) {
                      setState(() {
                        _moving = moving;
                        _fromLeft = fromLeft;
                      });
                    }
                  },
                  onDismissed: (_) => _delete(),
                  child: widget.child,
                ),
              ],
            ),
          ),
        );
}
