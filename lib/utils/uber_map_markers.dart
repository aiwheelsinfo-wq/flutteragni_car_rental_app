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

  /// Generate a high-resolution, realistic top-down car icon (like Uber/Ola)
  static Future<BitmapDescriptor> getTopDownCarMarker({
    Color bodyColor = const Color(0xFF1E1E1E), // Sleek black/dark charcoal car
    Color roofColor = const Color(0xFF2C2C2C),
    double width = 80,
    double height = 150,
  }) async {
    if (_cachedCarMarker != null) return _cachedCarMarker!;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final size = Size(width, height);

    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // 1. Soft Ambient Road Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 2), width: width * 0.72, height: height * 0.85),
        const Radius.circular(16),
      ),
      shadowPaint,
    );

    // 2. Wheels / Tires (4 tires peeking out slightly)
    final tirePaint = Paint()..color = const Color(0xFF111111);
    final tireWidth = width * 0.14;
    final tireHeight = height * 0.20;
    const tireRadius = Radius.circular(4);

    // Front Left & Right
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - width * 0.40, cy - height * 0.36, tireWidth, tireHeight), tireRadius),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx + width * 0.40 - tireWidth, cy - height * 0.36, tireWidth, tireHeight), tireRadius),
      tirePaint,
    );
    // Rear Left & Right
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - width * 0.40, cy + height * 0.16, tireWidth, tireHeight), tireRadius),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx + width * 0.40 - tireWidth, cy + height * 0.16, tireWidth, tireHeight), tireRadius),
      tirePaint,
    );

    // 3. Side Mirrors
    final mirrorPaint = Paint()..color = bodyColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - width * 0.44, cy - height * 0.20, width * 0.10, height * 0.08), const Radius.circular(3)),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx + width * 0.34, cy - height * 0.20, width * 0.10, height * 0.08), const Radius.circular(3)),
      mirrorPaint,
    );

    // 4. Main Car Body Chassis
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx, cy - height * 0.45),
        Offset(cx, cy + height * 0.45),
        [const Color(0xFF3A3A3A), bodyColor, const Color(0xFF151515)],
      );
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: width * 0.70, height: height * 0.88),
      const Radius.circular(18),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Subtle edge highlight
    final borderPaint = Paint()
      ..color = const Color(0xFFFFB300) // Rentox amber trim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(bodyRect, borderPaint);

    // 5. Front Windshield (Dark curved glass)
    final glassPaint = Paint()..color = const Color(0xFF0F172A);
    final frontGlassPath = Path()
      ..moveTo(cx - width * 0.26, cy - height * 0.16)
      ..quadraticBezierTo(cx, cy - height * 0.24, cx + width * 0.26, cy - height * 0.16)
      ..lineTo(cx + width * 0.22, cy - height * 0.04)
      ..quadraticBezierTo(cx, cy - height * 0.08, cx - width * 0.22, cy - height * 0.04)
      ..close();
    canvas.drawPath(frontGlassPath, glassPaint);

    // 6. Rear Windshield
    final rearGlassPath = Path()
      ..moveTo(cx - width * 0.22, cy + height * 0.18)
      ..quadraticBezierTo(cx, cy + height * 0.14, cx + width * 0.22, cy + height * 0.18)
      ..lineTo(cx + width * 0.24, cy + height * 0.28)
      ..quadraticBezierTo(cx, cy + height * 0.32, cx - width * 0.24, cy + height * 0.28)
      ..close();
    canvas.drawPath(rearGlassPath, glassPaint);

    // 7. Roof / Cabin Top
    final roofPaint = Paint()..color = roofColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + height * 0.05), width: width * 0.44, height: height * 0.24),
        const Radius.circular(6),
      ),
      roofPaint,
    );

    // 8. Headlights (Front Warm Glowing Accents)
    final headlightPaint = Paint()..color = const Color(0xFFFFF9C4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - width * 0.30, cy - height * 0.43, width * 0.14, height * 0.06), const Radius.circular(3)),
      headlightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx + width * 0.16, cy - height * 0.43, width * 0.14, height * 0.06), const Radius.circular(3)),
      headlightPaint,
    );

    // 9. Taillights (Rear Red Accents)
    final taillightPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - width * 0.28, cy + height * 0.40, width * 0.14, height * 0.04), const Radius.circular(2)),
      taillightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx + width * 0.14, cy + height * 0.40, width * 0.14, height * 0.04), const Radius.circular(2)),
      taillightPaint,
    );

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    _cachedCarMarker = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    return _cachedCarMarker!;
  }

  /// Uber-style Pickup Badge Marker (Green/Amber Pill + Pin Point)
  static Future<BitmapDescriptor> getPickupMarker({
    String label = "PICKUP",
    Color primaryColor = const Color(0xFF10B981), // Modern emerald green
  }) async {
    if (_cachedPickupMarker != null && label == "PICKUP") return _cachedPickupMarker!;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double width = 160;
    const double height = 75;

    // 1. Soft Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(8, 6, width - 16, 42), const Radius.circular(21)),
      shadowPaint,
    );

    // 2. Outer Capsule Pill
    final bgPaint = Paint()..color = primaryColor;
    final pillRRect = RRect.fromRectAndRadius(const Rect.fromLTWH(8, 4, width - 16, 42), const Radius.circular(21));
    canvas.drawRRect(pillRRect, bgPaint);

    // 3. White Border
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(pillRRect, strokePaint);

    // 4. Center Dot / Indicator Circle
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(28, 25), 6, dotPaint);
    canvas.drawCircle(const Offset(28, 25), 3, Paint()..color = primaryColor);

    // 5. Label Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(44, 25 - (textPainter.height / 2)));

    // 6. Bottom Pointer Triangle
    final pointerPath = Path()
      ..moveTo(width / 2 - 8, 46)
      ..lineTo(width / 2 + 8, 46)
      ..lineTo(width / 2, 58)
      ..close();
    canvas.drawPath(pointerPath, bgPaint);
    canvas.drawPath(pointerPath, strokePaint);

    // 7. Base Pin Dot
    canvas.drawCircle(const Offset(width / 2, 64), 5, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(const Offset(width / 2, 64), 2.5, Paint()..color = Colors.white);

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final desc = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    if (label == "PICKUP") _cachedPickupMarker = desc;
    return desc;
  }

  /// Uber-style Drop Badge Marker (Red Capsule + Pin Point)
  static Future<BitmapDescriptor> getDropMarker({
    String label = "DROP",
    Color primaryColor = const Color(0xFFDC2626), // Crimson red
  }) async {
    if (_cachedDropMarker != null && label == "DROP") return _cachedDropMarker!;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double width = 140;
    const double height = 75;

    // 1. Soft Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(8, 6, width - 16, 42), const Radius.circular(21)),
      shadowPaint,
    );

    // 2. Outer Capsule Pill
    final bgPaint = Paint()..color = primaryColor;
    final pillRRect = RRect.fromRectAndRadius(const Rect.fromLTWH(8, 4, width - 16, 42), const Radius.circular(21));
    canvas.drawRRect(pillRRect, bgPaint);

    // 3. White Border
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(pillRRect, strokePaint);

    // 4. Dot Indicator
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(26, 25), 6, dotPaint);
    canvas.drawCircle(const Offset(26, 25), 3, Paint()..color = primaryColor);

    // 5. Label Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(42, 25 - (textPainter.height / 2)));

    // 6. Pointer Triangle
    final pointerPath = Path()
      ..moveTo(width / 2 - 8, 46)
      ..lineTo(width / 2 + 8, 46)
      ..lineTo(width / 2, 58)
      ..close();
    canvas.drawPath(pointerPath, bgPaint);
    canvas.drawPath(pointerPath, strokePaint);

    // 7. Base Pin Dot
    canvas.drawCircle(const Offset(width / 2, 64), 5, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(const Offset(width / 2, 64), 2.5, Paint()..color = Colors.white);

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final desc = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
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
    this.speed = 0.00004,
  });

  void step() {
    // Subtle glide along heading
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
    final offsets = [
      [0.0042, 0.0031],
      [-0.0035, 0.0048],
      [0.0051, -0.0042],
      [-0.0048, -0.0033],
      [0.0022, -0.0061],
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
