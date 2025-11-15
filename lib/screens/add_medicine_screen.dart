import 'package:flutter/material.dart';
import '../models/medicine.dart';

class AddMedicineScreen extends StatefulWidget {
  final Function(Medicine)? onMedicineAdded;

  const AddMedicineScreen({super.key, this.onMedicineAdded});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  String _selectedFrequency = 'Once a day';
  List<TimeOfDay> _selectedTimes = [const TimeOfDay(hour: 9, minute: 0)];

  final frequencyOptions = [
    'Once a day',
    'Twice a day',
    'Three times a day',
    'As needed',
  ];
  final timeOptions = [
    '09:00 AM',
    '01:00 PM',
    '05:00 PM',
    '09:00 PM',
    'Custom',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Medicine'),
        backgroundColor: Colors.blue.shade600,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medicine Name
              const Text(
                'Medicine Name',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., Paracetamol',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.medication),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // Dosage
              const Text(
                'Dosage',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dosageController,
                decoration: InputDecoration(
                  hintText: 'e.g., 500mg',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.healing),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // Frequency
              const Text(
                'Frequency',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedFrequency,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.schedule),
                ),
                items: frequencyOptions.map((freq) {
                  return DropdownMenuItem(value: freq, child: Text(freq));
                }).toList(),
                onChanged: (value) {
                  setState(
                    () => _selectedFrequency = value ?? _selectedFrequency,
                  );
                },
              ),
              const SizedBox(height: 16),
              // Time
              const Text(
                'Reminder Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Time pickers for each dose based on selected frequency
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setStateInner) {
                  // determine count from selected frequency
                  int count = 1;
                  if (_selectedFrequency == 'Twice a day') count = 2;
                  if (_selectedFrequency == 'Three times a day') count = 3;
                  if (_selectedTimes.length != count) {
                    // adjust list length
                    _selectedTimes = List<TimeOfDay>.generate(
                      count,
                      (i) => i < _selectedTimes.length
                          ? _selectedTimes[i]
                          : const TimeOfDay(hour: 21, minute: 0),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(count, (i) {
                      final tod = _selectedTimes[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Dose ${i + 1} time: ${_formatTimeOfDay(tod)}',
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: tod,
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedTimes[i] = picked;
                                  });
                                  setStateInner(() {});
                                }
                              },
                              child: const Text('Pick Time'),
                            ),
                          ],
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 32),
              // Add Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _addMedicine,
                  child: const Text(
                    'Add Medicine',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addMedicine() {
    if (_formKey.currentState!.validate()) {
      // prepare times list
      final timesStr = _selectedTimes.map(_formatTimeOfDay).toList();
      final medicine = Medicine(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        dosage: _dosageController.text,
        frequency: _selectedFrequency,
        time: timesStr.isNotEmpty ? timesStr.first : '09:00 AM',
        times: timesStr,
        dateAdded: DateTime.now(),
      );

      if (widget.onMedicineAdded != null) {
        widget.onMedicineAdded!(medicine);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${medicine.name} added with reminders at ${medicine.times.join(', ')}!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
