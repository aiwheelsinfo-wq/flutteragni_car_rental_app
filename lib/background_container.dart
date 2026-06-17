import 'package:flutter/material.dart';

class BackgroundContainer extends StatelessWidget {
  final Widget child; // Accepts any widget as the main content
  final bool applyOverlay; // Optional dark overlay

  const BackgroundContainer(
      {Key? key, required this.child, this.applyOverlay = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.white], // ✅ Blue to White Gradient
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child, // ✅ Page content remains unchanged
    );
  }
}
