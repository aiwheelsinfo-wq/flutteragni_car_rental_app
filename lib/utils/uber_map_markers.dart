import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UberMapMarkers {
  static BitmapDescriptor? _cachedCarMarker;
  static BitmapDescriptor? _cachedPickupMarker;
  static BitmapDescriptor? _cachedDropMarker;

  /// Generate a compact, high-precision top-down car icon (Uber style)
  static Future<BitmapDescriptor> getTopDownCarMarker({
    Color bodyColor = const Color(0xFF1E1E1E), // Sleek black/dark charcoal
    Color roofColor = const Color(0xFF2C2C2C),
    double width = 32,
    double height = 58,
  }) async {
    if (_cachedCarMarker != null) return _cachedCarMarker!;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final size = Size(width, height);

    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // 1. Soft Road Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 1), width: width * 0.76, height: height * 0.88),
        const Radius.circular(6),
      ),
      shadowPaint,
    );

    // 2. Wheels / Tires (4 small black tires)
    final tirePaint = Paint()..color = const Color(0xFF111111);
    final tireW = width * 0.14;
    final tireH = height * 0.18;
    const tireR = Radius.circular(2);

    // Front Left & Right
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - width * 0.44, cy - height * 0.36, tireW, tireH), tireR),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx + width * 0.44 - tireW, cy - height * 0.36, tireW, tireH), tireR),
      tirePaint,
    );
    // Rear Left & Right
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - width * 0.44, cy + height * 0.18, tireW, tireH), tireR),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx + width * 0.44 - tireW, cy + height * 0.18, tireW, tireH), tireR),
      tirePaint,
    );

    // 3. Main Car Body Chassis
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx, cy - height * 0.45),
        Offset(cx, cy + height * 0.45),
        [const Color(0xFF3F3F46), bodyColor, const Color(0xFF18181B)],
        [0.0, 0.5, 1.0],
      );
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: width * 0.72, height: height * 0.88),
      const Radius.circular(7),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Subtle Amber outline for high visibility
    final borderPaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(bodyRect, borderPaint);

    // 4. Front Windshield (Dark glass)
    final glassPaint = Paint()..color = const Color(0xFF0F172A);
    final frontGlassPath = Path()
      ..moveTo(cx - width * 0.24, cy - height * 0.16)
      ..quadraticBezierTo(cx, cy - height * 0.22, cx + width * 0.24, cy - height * 0.16)
      ..lineTo(cx + width * 0.20, cy - height * 0.05)
      ..quadraticBezierTo(cx, cy - height * 0.08, cx - width * 0.20, cy - height * 0.05)
      ..close();
    canvas.drawPath(frontGlassPath, glassPaint);

    // 5. Rear Windshield
    final rearGlassPath = Path()
      ..moveTo(cx - width * 0.20, cy + height * 0.16)
      ..quadraticBezierTo(cx, cy + height * 0.12, cx + width * 0.20, cy + height * 0.16)
      ..lineTo(cx + width * 0.22, cy + height * 0.26)
      ..quadraticBezierTo(cx, cy + height * 0.30, cx - width * 0.22, cy + height * 0.26)
      ..close();
    canvas.drawPath(rearGlassPath, glassPaint);

    // 6. Roof / Cabin Top
    final roofPaint = Paint()..color = roofColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + height * 0.05), width: width * 0.44, height: height * 0.22),
        const Radius.circular(3),
      ),
      roofPaint,
    );

    // 7. Headlights (Front Glowing Yellow Accents)
    final headlightPaint = Paint()..color = const Color(0xFFFFF59D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - width * 0.28, cy - height * 0.42, width * 0.16, height * 0.06), const Radius.circular(1.5)),
      headlightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx + width * 0.12, cy - height * 0.42, width * 0.16, height * 0.06), const Radius.circular(1.5)),
      headlightPaint,
    );

    // 8. Taillights (Rear Red LED Accents)
    final taillightPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - width * 0.26, cy + height * 0.38, width * 0.16, height * 0.04), const Radius.circular(1)),
      taillightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx + width * 0.10, cy + height * 0.38, width * 0.16, height * 0.04), const Radius.circular(1)),
      taillightPaint,
    );

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final Uint8List uint8List = byteData!.buffer.asUint8List();
    _cachedCarMarker = BitmapDescriptor.bytes(uint8List);
    return _cachedCarMarker!;
  }

  /// Compact Uber-style Pickup Badge Marker
  static Future<BitmapDescriptor> getPickupMarker({
    String label = "PICKUP",
    Color primaryColor = const Color(0xFF10B981), // Emerald green
  }) async {
    if (_cachedPickupMarker != null && label == "PICKUP") return _cachedPickupMarker!;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double width = 80;
    const double height = 34;

    // 1. Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(4, 3, width - 8, 22), const Radius.circular(11)),
      shadowPaint,
    );

    // 2. Outer Capsule Pill
    final bgPaint = Paint()..color = primaryColor;
    final pillRRect = RRect.fromRectAndRadius(const Rect.fromLTWH(4, 2, width - 8, 22), const Radius.circular(11));
    canvas.drawRRect(pillRRect, bgPaint);

    // 3. White Border
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(pillRRect, strokePaint);

    // 4. Indicator Dot
    canvas.drawCircle(const Offset(14, 13), 3.5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(14, 13), 1.8, Paint()..color = primaryColor);

    // 5. Label Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(22, 13 - (textPainter.height / 2)));

    // 6. Bottom Pointer Triangle
    final pointerPath = Path()
      ..moveTo(width / 2 - 4, 23)
      ..lineTo(width / 2 + 4, 23)
      ..lineTo(width / 2, 29)
      ..close();
    canvas.drawPath(pointerPath, bgPaint);
    canvas.drawPath(pointerPath, strokePaint);

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final Uint8List uint8List = byteData!.buffer.asUint8List();
    final desc = BitmapDescriptor.bytes(uint8List);
    if (label == "PICKUP") _cachedPickupMarker = desc;
    return desc;
  }

  /// Compact Uber-style Drop Badge Marker
  static Future<BitmapDescriptor> getDropMarker({
    String label = "DROP",
    Color primaryColor = const Color(0xFFDC2626), // Crimson red
  }) async {
    if (_cachedDropMarker != null && label == "DROP") return _cachedDropMarker!;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double width = 72;
    const double height = 34;

    // 1. Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(4, 3, width - 8, 22), const Radius.circular(11)),
      shadowPaint,
    );

    // 2. Outer Capsule Pill
    final bgPaint = Paint()..color = primaryColor;
    final pillRRect = RRect.fromRectAndRadius(const Rect.fromLTWH(4, 2, width - 8, 22), const Radius.circular(11));
    canvas.drawRRect(pillRRect, bgPaint);

    // 3. White Border
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(pillRRect, strokePaint);

    // 4. Dot Indicator
    canvas.drawCircle(const Offset(13, 13), 3.5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(13, 13), 1.8, Paint()..color = primaryColor);

    // 5. Label Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(21, 13 - (textPainter.height / 2)));

    // 6. Pointer Triangle
    final pointerPath = Path()
      ..moveTo(width / 2 - 4, 23)
      ..lineTo(width / 2 + 4, 23)
      ..lineTo(width / 2, 29)
      ..close();
    canvas.drawPath(pointerPath, bgPaint);
    canvas.drawPath(pointerPath, strokePaint);

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final Uint8List uint8List = byteData!.buffer.asUint8List();
    final desc = BitmapDescriptor.bytes(uint8List);
    if (label == "DROP") _cachedDropMarker = desc;
    return desc;
  }
}

/// Simulated Nearby Cab for Uber Discovery Effect around Pickup Point
class NearbyCab {
  final String id;
  LatLng position;
  double heading;
  final double speed;

  NearbyCab({
    required this.id,
    required this.position,
    required this.heading,
    this.speed = 0.00003,
  });

  void step() {
    // Glide along heading
    final rad = heading * (math.pi / 180.0);
    position = LatLng(
      position.latitude + (math.cos(rad) * speed * (0.8 + math.Random().nextDouble() * 0.4)),
      position.longitude + (math.sin(rad) * speed * (0.8 + math.Random().nextDouble() * 0.4)),
    );
    // Subtle rotation jitter
    heading = (heading + (math.Random().nextDouble() * 4 - 2)) % 360;
  }

  static List<NearbyCab> generateAround(LatLng center, {int count = 4}) {
    final random = math.Random(center.latitude.toInt() + center.longitude.toInt());
    final List<NearbyCab> cabs = [];
    // Spread cabs nicely so they don't clump together
    final offsets = [
      [0.0060, 0.0045],
      [-0.0055, 0.0065],
      [0.0070, -0.0050],
      [-0.0065, -0.0045],
    ];

    for (int i = 0; i < count && i < offsets.length; i++) {
      final off = offsets[i];
      final cabPos = LatLng(
        center.latitude + off[0] + (random.nextDouble() * 0.001 - 0.0005),
        center.longitude + off[1] + (random.nextDouble() * 0.001 - 0.0005),
      );
      final angle = (random.nextDouble() * 360);
      cabs.add(NearbyCab(
        id: "cab_$i",
        position: cabPos,
        heading: angle,
      ));
    }
    return cabs;
  }
}

