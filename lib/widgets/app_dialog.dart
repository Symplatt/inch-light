import 'package:flutter/material.dart';

/// Dialog surfaces use their measured height, not their content's estimate.
double dialogCenterFraction(double ratio) => switch (ratio) {
  < 0.25 => 0.45,
  < 0.45 => 0.46,
  < 0.65 => 0.48,
  _ => 0.50,
};

class AppDialog extends Dialog {
  const AppDialog({
    super.key,
    super.child,
    super.backgroundColor,
    super.elevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.insetPadding,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.semanticsRole,
  });

  factory AppDialog.from(Dialog dialog) => AppDialog(
    child: dialog.child,
    backgroundColor: dialog.backgroundColor,
    elevation: dialog.elevation,
    shadowColor: dialog.shadowColor,
    surfaceTintColor: dialog.surfaceTintColor,
    insetPadding: dialog.insetPadding,
    shape: dialog.shape,
    clipBehavior: dialog.clipBehavior,
    constraints: dialog.constraints,
    semanticsRole: dialog.semanticsRole,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogTheme = DialogTheme.of(context);
    final view = View.of(context);
    final height = view.physicalSize.height / view.devicePixelRatio;
    // showDialog's SafeArea already removes the physical top safe inset.
    final safeTop = view.padding.top / view.devicePixelRatio;
    final padding =
        MediaQuery.viewInsetsOf(context) +
        (insetPadding ??
            dialogTheme.insetPadding ??
            const EdgeInsets.symmetric(horizontal: 40, vertical: 24));
    return Semantics(
      role: semanticsRole,
      child: TweenAnimationBuilder<EdgeInsets>(
        tween: EdgeInsetsTween(begin: padding, end: padding),
        duration: insetAnimationDuration,
        curve: insetAnimationCurve,
        builder: (context, animatedPadding, child) => Padding(
          padding: animatedPadding,
          child: CustomSingleChildLayout(
            delegate: _DialogLayout(height, safeTop + animatedPadding.top),
            child: child,
          ),
        ),
        child: MediaQuery.removeViewInsets(
          context: context,
          removeLeft: true,
          removeTop: true,
          removeRight: true,
          removeBottom: true,
          child: ConstrainedBox(
            constraints:
                constraints ??
                dialogTheme.constraints ??
                const BoxConstraints(minWidth: 280),
            child: Material(
              type: MaterialType.card,
              color:
                  backgroundColor ??
                  dialogTheme.backgroundColor ??
                  theme.colorScheme.surfaceContainerHigh,
              elevation: elevation ?? dialogTheme.elevation ?? 6,
              shadowColor: shadowColor ?? dialogTheme.shadowColor,
              surfaceTintColor:
                  surfaceTintColor ?? dialogTheme.surfaceTintColor,
              shape:
                  shape ??
                  dialogTheme.shape ??
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
              clipBehavior:
                  clipBehavior ?? dialogTheme.clipBehavior ?? Clip.none,
              child: this.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogLayout extends SingleChildLayoutDelegate {
  const _DialogLayout(this.screenHeight, this.top);
  final double screenHeight;
  final double top;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final center =
        screenHeight * dialogCenterFraction(childSize.height / screenHeight);
    return Offset(
      (size.width - childSize.width) / 2,
      (center - top - childSize.height / 2).clamp(
        0.0,
        (size.height - childSize.height).clamp(0.0, double.infinity),
      ),
    );
  }

  @override
  bool shouldRelayout(_DialogLayout oldDelegate) =>
      screenHeight != oldDelegate.screenHeight || top != oldDelegate.top;
}

/// Reuse Flutter's title/content/actions layout and only position its surface.
class AppAlertDialog extends AlertDialog {
  const AppAlertDialog({
    super.key,
    super.title,
    super.content,
    super.actions,
    super.titlePadding,
    super.titleTextStyle,
    super.contentPadding,
    super.actionsPadding,
    super.actionsAlignment,
    super.backgroundColor,
    super.surfaceTintColor,
    super.shape,
    super.insetPadding,
    super.scrollable,
    super.constraints,
  });

  @override
  Widget build(BuildContext context) =>
      AppDialog.from(super.build(context) as Dialog);
}

class AppSimpleDialog extends SimpleDialog {
  const AppSimpleDialog({super.key, super.title, super.children});

  @override
  Widget build(BuildContext context) =>
      AppDialog.from(super.build(context) as Dialog);
}
