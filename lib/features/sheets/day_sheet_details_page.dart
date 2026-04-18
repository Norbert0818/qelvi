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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Edit details'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + bottomSafe + 24),
          children: [
            TextField(
              controller: vehicleTypeController,
              decoration: const InputDecoration(labelText: 'Vehicle type'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: fuelTypeController,
              decoration: const InputDecoration(labelText: 'Fuel type'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: carNumberController,
              decoration: const InputDecoration(labelText: 'Car number'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: driverNameController,
              decoration: const InputDecoration(labelText: 'Driver name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: eventNameController,
              decoration: const InputDecoration(labelText: 'Event name'),
            ),
          ],
        ),
      ),
    );
  }
}