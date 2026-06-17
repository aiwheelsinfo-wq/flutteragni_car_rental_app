import 'package:flutter/material.dart';

class PointsWidget extends StatelessWidget {
  final int points;
  final VoidCallback onTap;

  const PointsWidget({
    super.key,
    required this.points,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            height: 35,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 211, 255, 178),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color.fromARGB(255, 43, 255, 0), width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // const Icon(Icons.monetization_on,
                //     color: Colors.amber, size: 20),
                // const SizedBox(width: 6),
                Text(
                  '💸${points.toString()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
