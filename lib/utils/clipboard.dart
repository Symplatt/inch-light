import 'package:flutter/services.dart';

/// Verify the write so a transient platform failure is retried within one tap.
Future<void> copyText(String text) async {
  for (var attempt = 0; attempt < 2; attempt++) {
    await Clipboard.setData(ClipboardData(text: text));
    final read = await Clipboard.getData(Clipboard.kTextPlain);
    if (read?.text == text) return;
  }
  throw StateError('剪贴板写入未成功');
}
