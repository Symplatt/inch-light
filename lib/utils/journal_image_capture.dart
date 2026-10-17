import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

// Render strips at the screen's actual density. Long notes must never shrink
// to fit a texture or pixel budget; compress strips as they are read instead.
Future<Uint8List> captureJournalPng(
  RenderRepaintBoundary boundary,
  double pixelRatio,
) async {
  final width = (boundary.size.width * pixelRatio).ceil();
  final height = (boundary.size.height * pixelRatio).ceil();
  // Access the painted layer to rasterize strips without a full-height texture.
  // ignore: invalid_use_of_protected_member
  final layer = boundary.layer! as OffsetLayer;
  final output = BytesBuilder(copy: false);
  output.add([137, 80, 78, 71, 13, 10, 26, 10]);
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
  _pngChunk(output, 'IHDR', header.buffer.asUint8List());
  final compressed = ZLibEncoder().startChunkedConversion(
    ByteConversionSink.withCallback(
      (bytes) => _pngChunk(output, 'IDAT', bytes),
    ),
  );
  for (var y = 0; y < height; y += 1024) {
    final rows = math.min(1024, height - y);
    final image = await layer.toImage(
      ui.Rect.fromLTWH(
        0,
        y / pixelRatio,
        width / pixelRatio,
        rows / pixelRatio,
      ),
      pixelRatio: pixelRatio,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('图片生成失败');
      final rgba = data.buffer.asUint8List();
      final strip = Uint8List(rows * (width * 4 + 1));
      for (var row = 0; row < rows; row++) {
        // PNG filter 0 preserves every source pixel; each row starts with 0.
        strip.setRange(
          row * (width * 4 + 1) + 1,
          (row + 1) * (width * 4 + 1),
          rgba,
          row * image.width * 4,
        );
      }
      compressed.add(strip);
    } finally {
      image.dispose();
    }
  }
  compressed.close();
  _pngChunk(output, 'IEND', []);
  return output.takeBytes();
}

void _pngChunk(BytesBuilder output, String type, List<int> bytes) {
  final name = ascii.encode(type);
  var crc = 0xffffffff;
  for (final byte in [...name, ...bytes]) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? 0xedb88320 ^ (crc >>> 1) : crc >>> 1;
    }
  }
  output.add((ByteData(4)..setUint32(0, bytes.length)).buffer.asUint8List());
  output.add(name);
  output.add(bytes);
  output.add(
    (ByteData(4)..setUint32(0, crc ^ 0xffffffff)).buffer.asUint8List(),
  );
}
