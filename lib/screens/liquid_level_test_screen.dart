import 'package:flutter/material.dart';
import '../models/liquid_level.dart';
import '../services/liquid_level_service.dart';

class LiquidLevelTestScreen extends StatefulWidget {
  const LiquidLevelTestScreen({super.key});

  @override
  State<LiquidLevelTestScreen> createState() => _LiquidLevelTestScreenState();
}

class _LiquidLevelTestScreenState extends State<LiquidLevelTestScreen> {
  LiquidLevel? _liquidLevel;
  bool _isLoading = true;
  late TextEditingController _capacityController;

  @override
  void initState() {
    super.initState();
    _capacityController = TextEditingController();
    _loadLiquidLevel();
  }

  Future<void> _loadLiquidLevel() async {
    try {
      final bottle = await LiquidLevelService.getDefaultBottle();
      if (mounted) {
        setState(() {
          _liquidLevel = bottle;
          _capacityController.text = bottle.capacity.toStringAsFixed(0);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading liquid level: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Manual level updates and quick-set buttons removed per UX requirement.

  Future<void> _updateCapacity(double newCapacity) async {
    if (_liquidLevel == null) return;

    try {
      final updated = _liquidLevel!.copyWith(capacity: newCapacity);
      await LiquidLevelService.writeLiquidLevel(updated);
      await _loadLiquidLevel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Capacity updated successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error updating capacity: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Liquid Level'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _liquidLevel == null
          ? const Center(child: Text('Failed to load liquid level'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Status Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Bottle Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bottle Name:',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _liquidLevel!.bottleName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Percentage:',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _liquidLevel!.isLow
                                          ? Colors.red.shade100
                                          : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${_liquidLevel!.percentageLevel.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _liquidLevel!.isLow
                                            ? Colors.red.shade900
                                            : Colors.green.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Level:',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${_liquidLevel!.currentLevel.toStringAsFixed(1)} ml',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Capacity:',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${_liquidLevel!.capacity.toStringAsFixed(0)} ml',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bottle Capacity Selector
                  const Text(
                    'Bottle Capacity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _capacityController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Capacity (ml)',
                            hintText: 'Enter capacity',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixText: 'ml',
                          ),
                          onSubmitted: (value) {
                            final cap = double.tryParse(value);
                            if (cap != null && cap > 0) {
                              _updateCapacity(cap);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.all(14),
                        ),
                        onPressed: () {
                          final cap = double.tryParse(_capacityController.text);
                          if (cap != null && cap > 0) {
                            _updateCapacity(cap);
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter a valid capacity'),
                                ),
                              );
                            }
                          }
                        },
                        child: const Icon(Icons.check),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // No quick-percentage buttons
}
