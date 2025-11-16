import 'package:flutter/material.dart';
import '../models/medicine.dart';

class AddMedicineScreen extends StatefulWidget {
  final Function(Medicine)? onMedicineAdded;
  final Medicine? medicineToEdit;

  const AddMedicineScreen({
    super.key,
    this.onMedicineAdded,
    this.medicineToEdit,
  });

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  String _selectedFrequency = 'Once a day';
  List<TimeOfDay> _selectedTimes = [const TimeOfDay(hour: 9, minute: 0)];
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  Set<String> _selectedDays = {
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  };

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
  void initState() {
    super.initState();
    if (widget.medicineToEdit != null) {
      final med = widget.medicineToEdit!;
      _nameController.text = med.name;
      _dosageController.text = med.dosage;
      _selectedFrequency = med.frequency;
      _selectedDays = Set<String>.from(med.weeklyDays);
      _selectedTimes = med.times.map((timeStr) {
        try {
          final parts = timeStr.split(' ');
          final hm = parts[0].split(':');
          final hour = int.parse(hm[0]);
          final minute = int.parse(hm[1]);
          return TimeOfDay(hour: hour, minute: minute);
        } catch (_) {
          return const TimeOfDay(hour: 9, minute: 0);
        }
      }).toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.medicineToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Medicine' : 'Add Medicine',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade50,
                      Colors.blue.shade100.withOpacity(0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200, width: 2),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.blue.shade300, Colors.blue.shade600],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_note : Icons.add_circle,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Update Your Medicine'
                                : 'Add New Medicine',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEditing
                                ? 'Modify medicine details below'
                                : 'Fill in the details to add a new medicine',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Medicine Name
              _buildFormSection(
                label: 'Medicine Name',
                icon: Icons.medication_liquid,
                child: TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Paracetamol',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue.shade600,
                        width: 2,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.medication_liquid,
                      color: Colors.blue.shade600,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  style: const TextStyle(fontSize: 16),
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Medicine name is required'
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // Dosage
              _buildFormSection(
                label: 'Dosage',
                icon: Icons.local_hospital,
                child: TextFormField(
                  controller: _dosageController,
                  decoration: InputDecoration(
                    hintText: 'e.g., 500mg',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue.shade600,
                        width: 2,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.local_hospital,
                      color: Colors.blue.shade600,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  style: const TextStyle(fontSize: 16),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Dosage is required' : null,
                ),
              ),
              const SizedBox(height: 20),

              // Frequency
              _buildFormSection(
                label: 'Frequency',
                icon: Icons.schedule,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedFrequency,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue.shade600,
                        width: 2,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.schedule,
                      color: Colors.blue.shade600,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
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
              ),
              const SizedBox(height: 24),

              // Reminder Times
              _buildFormSection(
                label: 'Reminder Times',
                icon: Icons.access_time,
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setStateInner) {
                  // Determine count from selected frequency
                  int count = 1;
                  if (_selectedFrequency == 'Twice a day') count = 2;
                  if (_selectedFrequency == 'Three times a day') count = 3;
                  if (_selectedTimes.length != count) {
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
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue.shade50,
                                Colors.blue.shade100.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dose ${i + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatTimeOfDay(tod),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
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
                                  icon: const Icon(Icons.access_time, size: 18),
                                  label: const Text('Change'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Weekly Days Selection
              _buildFormSection(
                label: 'Select Days',
                icon: Icons.calendar_today,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade50,
                      Colors.blue.shade100.withOpacity(0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200, width: 1.5),
                ),
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _daysOfWeek.map((day) {
                    final isSelected = _selectedDays.contains(day);
                    return FilterChip(
                      label: Text(day.substring(0, 3)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedDays.add(day);
                          } else {
                            _selectedDays.remove(day);
                          }
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: Colors.blue.shade400,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.blue.shade700,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.blue.shade400
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 36),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _saveMedicine,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isEditing ? Icons.update : Icons.check_circle,
                        size: 22,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEditing ? 'Update Medicine' : 'Add Medicine',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection({
    required String label,
    required IconData icon,
    Widget? child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blue.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (child != null) child,
      ],
    );
  }

  void _saveMedicine() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one day'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // prepare times list
      final timesStr = _selectedTimes.map(_formatTimeOfDay).toList();
      final medicine = Medicine(
        id:
            widget.medicineToEdit?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        dosage: _dosageController.text,
        frequency: _selectedFrequency,
        time: timesStr.isNotEmpty ? timesStr.first : '09:00 AM',
        times: timesStr,
        dateAdded: widget.medicineToEdit?.dateAdded ?? DateTime.now(),
        weeklyDays: _selectedDays.toList(),
      );

      if (widget.onMedicineAdded != null) {
        widget.onMedicineAdded!(medicine);
      } else {
        // Fallback if no callback is provided
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${medicine.name} ${widget.medicineToEdit != null ? 'updated' : 'added'} with reminders at ${medicine.times.join(', ')}!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
