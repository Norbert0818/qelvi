import 'package:flutter/material.dart';
import 'models/day_sheet.dart';

class DaySheetDetailsPage extends StatefulWidget {
  final DaySheet daySheet;

  const DaySheetDetailsPage({
    super.key,
    required this.daySheet,
  });

  @override
  State<DaySheetDetailsPage> createState() => _DaySheetDetailsPageState();
}

class _DaySheetDetailsPageState extends State<DaySheetDetailsPage> {
  late TextEditingController vehicleTypeController;
  late TextEditingController fuelTypeController;
  late TextEditingController carNumberController;
  late TextEditingController driverNameController;
  late TextEditingController eventNameController;

  @override
  void initState() {
    super.initState();
    vehicleTypeController =
        TextEditingController(text: widget.daySheet.vehicleType);
    fuelTypeController =
        TextEditingController(text: widget.daySheet.fuelType);
    carNumberController =
        TextEditingController(text: widget.daySheet.carNumber);
    driverNameController =
        TextEditingController(text: widget.daySheet.driverName);
    eventNameController =
        TextEditingController(text: widget.daySheet.eventName);
  }

  @override
  void dispose() {
    vehicleTypeController.dispose();
    fuelTypeController.dispose();
    carNumberController.dispose();
    driverNameController.dispose();
    eventNameController.dispose();
    super.dispose();
  }

  void _save() {
    final updated = DaySheet(
      id: widget.daySheet.id,
      vehicleType: vehicleTypeController.text.trim(),
      fuelType: fuelTypeController.text.trim(),
      date: widget.daySheet.date,
      carNumber: carNumberController.text.trim(),
      driverName: driverNameController.text.trim(),
      eventName: eventNameController.text.trim(),
      isArchived: widget.daySheet.isArchived,
      rows: widget.daySheet.rows,
    );

    Navigator.pop(context, updated);
  }

  // Modern input decoration helper
  InputDecoration _modernInput(String label, IconData icon, Color iconColor) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 22, color: iconColor),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Edit details',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.tonal(
              onPressed: _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 24, 16, bottomInset + bottomSafe + 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'General Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: driverNameController,
                    decoration: _modernInput('Driver name', Icons.person, Colors.teal.shade500),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: carNumberController,
                    decoration: _modernInput('Car number', Icons.pin, Colors.indigo.shade500),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: vehicleTypeController,
                    decoration: _modernInput('Vehicle type', Icons.directions_car, Colors.blue.shade500),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: fuelTypeController,
                    decoration: _modernInput('Fuel type', Icons.local_gas_station, Colors.orange.shade500),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.event, size: 20, color: Colors.purple.shade700),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Event Binding',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: eventNameController,
                    decoration: _modernInput('Event name', Icons.celebration, Colors.purple.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}