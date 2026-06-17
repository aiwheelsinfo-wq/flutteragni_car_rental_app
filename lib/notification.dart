import 'package:flutter/material.dart';

class InAppNotificationService {
  static OverlayEntry? _currentEntry;

  static void show(BuildContext context, String imageUrl) {
    // prevent duplicate
    if (_currentEntry != null) return;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 40,
        left: 10,
        right: 10,
        child: _NotificationCard(imageUrl: imageUrl),
      ),
    );

    overlay.insert(_currentEntry!);

    // auto remove
    Future.delayed(const Duration(seconds: 4), () {
      hide();
    });
  }

  static void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _NotificationCard extends StatelessWidget {
  final String imageUrl;

  const _NotificationCard({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "New offer available",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
