import 'package:flutter/material.dart';

/// A reusable bottle widget that displays current liquid level.
/// Supports both vertical and horizontal orientations.
class LiquidBottleWidget extends StatelessWidget {
  final double capacity;
  final double currentLevel;
  final double width;
  final double height;
  final bool showPercentage;
  final bool isHorizontal; // New parameter for orientation

  const LiquidBottleWidget({
    super.key,
    required this.capacity,
    required this.currentLevel,
    this.width = 64,
    this.height = 140,
    this.showPercentage = true,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final pct = capacity <= 0 ? 0.0 : (currentLevel / capacity).clamp(0.0, 1.0);

    if (isHorizontal) {
      return _buildHorizontalBottle(pct);
    } else {
      return _buildVerticalBottle(pct);
    }
  }

  Widget _buildVerticalBottle(double pct) {
    final fillHeight = pct * (height - 12); // leave padding for cap

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bottle outline
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400, width: 2),
              color: Colors.transparent,
            ),
          ),
          // Fill container (positioned at bottom)
          Positioned(
            bottom: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: width - 8,
                height: fillHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blue.shade300.withValues(alpha: 0.9),
                      Colors.blue.shade700,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Percentage label overlay
          if (showPercentage)
            Positioned(
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: pct < 0.2 ? Colors.red : Colors.blue.shade900,
                  ),
                ),
              ),
            ),
          // Small cap decoration
          Positioned(
            top: -6,
            child: Container(
              width: width * 0.36,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade400, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalBottle(double pct) {
    final fillWidth = pct * (width - 12); // leave padding for cap

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bottle outline
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400, width: 2),
              color: Colors.transparent,
            ),
          ),
          // Fill container (positioned at left)
          Positioned(
            left: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: fillWidth,
                height: height - 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.blue.shade300.withValues(alpha: 0.9),
                      Colors.blue.shade700,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Percentage label overlay
          if (showPercentage)
            Positioned(
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: pct < 0.2 ? Colors.red : Colors.blue.shade900,
                  ),
                ),
              ),
            ),
          // Small cap decoration (right side)
          Positioned(
            right: -6,
            child: Container(
              width: 10,
              height: height * 0.36,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade400, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
