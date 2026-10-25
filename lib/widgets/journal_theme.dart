import 'package:flutter/material.dart';

class JournalTheme extends StatelessWidget {
  const JournalTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final source = Theme.of(context);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF404040),
          dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
        ).copyWith(
          primary: const Color(0xFF404040),
          error: const Color(0xFF606060),
          onError: Colors.white,
          errorContainer: const Color(0xFFEDEDED),
          onErrorContainer: const Color(0xFF303030),
          surface: Colors.white,
          surfaceTint: Colors.transparent,
        );
    return Theme(
      data: source.copyWith(
        colorScheme: scheme,
        primaryColor: scheme.primary,
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        dividerColor: const Color(0xFFEBEBEB),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF404040),
          selectionColor: Color(0x40606060),
          selectionHandleColor: Color(0xFF606060),
        ),
        appBarTheme: source.appBarTheme.copyWith(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF252525),
          surfaceTintColor: Colors.transparent,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: child,
    );
  }
}
