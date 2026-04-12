import 'package:flutter/material.dart';
import 'models/day_sheet.dart';
import 'models/trip_row.dart';

class DaySheetEditorPage extends StatefulWidget {
  final DaySheet daySheet;
  final ValueChanged<DaySheet> onSave;

  const DaySheetEditorPage({
    super.key,
    required this.daySheet,
    required this.onSave,
  });

  @override
  State<DaySheetEditorPage> createState() => _DaySheetEditorPageState();
}

class _DaySheetEditorPageState extends State<DaySheetEditorPage> {
  late TextEditingController vehicleTypeController;
  late TextEditingController fuelTypeController;
  late TextEditingController dateController;
  late TextEditingController carNumberController;
  late TextEditingController driverNameController;
  late TextEditingController eventNameController;

  late List<TripRow> rows;

  @override
  void initState() {
    super.initState();

    vehicleTypeController =
        TextEditingController(text: widget.daySheet.vehicleType);
    fuelTypeController =
        TextEditingController(text: widget.daySheet.fuelType);
    dateController =
        TextEditingController(text: widget.daySheet.date);
    carNumberController =
        TextEditingController(text: widget.daySheet.carNumber);
    driverNameController =
        TextEditingController(text: widget.daySheet.driverName);
    eventNameController =
        TextEditingController(text: widget.daySheet.eventName);

    rows = widget.daySheet.rows
        .map(
          (e) => TripRow(
        departurePlace: e.departurePlace,
        departureTime: e.departureTime,
        arrivalPlace: e.arrivalPlace,
        arrivalTime: e.arrivalTime,
        km: e.km,
      ),
    )
        .toList();
  }

  @override
  void dispose() {
    vehicleTypeController.dispose();
    fuelTypeController.dispose();
    dateController.dispose();
    carNumberController.dispose();
    driverNameController.dispose();
    eventNameController.dispose();
    super.dispose();
  }

  void _addRow() {
    setState(() {
      rows.add(
        TripRow(
          departurePlace: '',
          departureTime: '',
          arrivalPlace: '',
          arrivalTime: '',
          km: 0,
        ),
      );
    });
  }

  void _save() {
    final updated = DaySheet(
      id: widget.daySheet.id,
      vehicleType: vehicleTypeController.text.trim(),
      fuelType: fuelTypeController.text.trim(),
      date: dateController.text.trim(),
      carNumber: carNumberController.text.trim(),
      driverName: driverNameController.text.trim(),
      eventName: eventNameController.text.trim(),
      rows: rows,
    );

    widget.onSave(updated);
    Navigator.pop(context);
  }

  Widget _buildRowEditor(int index) {
    final row = rows[index];

    final departurePlaceController =
    TextEditingController(text: row.departurePlace);
    final departureTimeController =
    TextEditingController(text: row.departureTime);
    final arrivalPlaceController =
    TextEditingController(text: row.arrivalPlace);
    final arrivalTimeController = TextEditingController(text: row.arrivalTime);
    final kmController =
    TextEditingController(text: row.km == 0 ? '' : row.km.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    rows.removeAt(index);
                  });
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ),
            TextField(
              controller: departurePlaceController,
              decoration: const InputDecoration(labelText: 'Departure place'),
              onChanged: (value) => row.departurePlace = value,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: departureTimeController,
              decoration: const InputDecoration(labelText: 'Departure time'),
              onChanged: (value) => row.departureTime = value,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: arrivalPlaceController,
              decoration: const InputDecoration(labelText: 'Arrival place'),
              onChanged: (value) => row.arrivalPlace = value,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: arrivalTimeController,
              decoration: const InputDecoration(labelText: 'Arrival time'),
              onChanged: (value) => row.arrivalTime = value,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: kmController,
              decoration: const InputDecoration(labelText: 'KM'),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                row.km = double.tryParse(value.replaceAll(',', '.')) ?? 0;
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit day sheet'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
            controller: dateController,
            decoration: const InputDecoration(labelText: 'Date'),
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
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trip rows',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _addRow,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          ...List.generate(rows.length, _buildRowEditor),
        ],
      ),
    );
  }
}