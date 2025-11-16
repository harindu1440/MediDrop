import 'package:flutter/material.dart';
import '../models/liquid_level.dart';

class LiquidLevelBar extends StatelessWidget {
  final LiquidLevel liquidLevel;
  final double height;
  final bool showLabel;

  const LiquidLevelBar({
    super.key,
    required this.liquidLevel,
    this.height = 60,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = liquidLevel.percentageLevel.clamp(0.0, 100.0) / 100;
    final isLow = liquidLevel.isLow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with bottle name and percentage
        if (showLabel)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                liquidLevel.bottleName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLow ? Colors.red.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${liquidLevel.percentageLevel.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isLow ? Colors.red.shade900 : Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
        if (showLabel) const SizedBox(height: 8),

        // Liquid level bar container
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(
              color: isLow ? Colors.red.shade300 : Colors.grey.shade300,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade50,
          ),
          child: Stack(
            children: [
              // Filled portion
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity * percentage,
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isLow
                          ? [Colors.red.shade300, Colors.red.shade600]
                          : [Colors.blue.shade300, Colors.blue.shade600],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Wave-like pattern
                      Opacity(
                        opacity: 0.3,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white30, Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Center text showing ml information
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${liquidLevel.currentLevel.toStringAsFixed(1)}ml',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'of ${liquidLevel.capacity.toStringAsFixed(0)}ml',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Warning message if low
        if (isLow) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red.shade900, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Low liquid level - Refill soon!',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
