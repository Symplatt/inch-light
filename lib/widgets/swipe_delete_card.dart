import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Paint under the entire rounded card, including the moving edge's corners.
class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key});
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.danger,
    child: Padding(
      padding: EdgeInsets.only(right: 20),
      child: Align(
        alignment: Alignment.centerRight,
        child: Icon(Icons.delete_outline, color: Colors.white),
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
  });
  final String id;
  final bool enabled;
  final Widget child;
  final FutureOr<void> Function() onDeleted;
  final double radius;
  final double bottomMargin;
  @override
  State<SwipeDeleteCard> createState() => _SwipeDeleteCardState();
}

class _SwipeDeleteCardState extends State<SwipeDeleteCard> {
  bool _moving = false;
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
            borderRadius: BorderRadius.circular(widget.radius),
            child: Stack(
              children: [
                if (_moving)
                  const Positioned.fill(child: SwipeDeleteBackground()),
                Dismissible(
                  key: ValueKey('${widget.id}:$_attempt'),
                  direction: widget.enabled
                      ? DismissDirection.endToStart
                      : DismissDirection.none,
                  onUpdate: (details) {
                    final moving = details.progress > 0;
                    if (_moving != moving) setState(() => _moving = moving);
                  },
                  onDismissed: (_) => _delete(),
                  child: widget.child,
                ),
              ],
            ),
          ),
        );
}
