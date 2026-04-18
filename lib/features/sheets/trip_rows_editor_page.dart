import 'package:flutter/material.dart';
import 'models/day_sheet.dart';
import 'models/trip_row.dart';

class TripRowsEditorPage extends StatefulWidget {
  final DaySheet daySheet;

  const TripRowsEditorPage({
    super.key,
    required this.daySheet,
  });

  @override
  State<TripRowsEditorPage> createState() => _TripRowsEditorPageState();
}

class _TripRowsEditorPageState extends State<TripRowsEditorPage> {
  late List<TripRow> rows;

  @override
  void initState() {
    super.initState();
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
      vehicleType: widget.daySheet.vehicleType,
      fuelType: widget.daySheet.fuelType,
      date: widget.daySheet.date,
      carNumber: widget.daySheet.carNumber,
      driverName: widget.daySheet.driverName,
      eventName: widget.daySheet.eventName,
      isArchived: widget.daySheet.isArchived,
      rows: rows,
    );

    Navigator.pop(context, updated);
  }

  Widget _buildRowEditor(int index) {
    final row = rows[index];

    final departurePlaceController =
    TextEditingController(text: row.departurePlace);
    final departureTimeController =
    TextEditingController(text: row.departureTime);
    final arrivalPlaceController =
    TextEditingController(text: row.arrivalPlace);
    final arrivalTimeController =
    TextEditingController(text: row.arrivalTime);
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('Trip rows - ${widget.daySheet.date}'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRow,
        icon: const Icon(Icons.add),
        label: const Text('Add row'),
      ),
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            bottomInset + bottomSafe + 100,
          ),
          children: [
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No trip rows for this day yet.'),
                ),
              ),
            ...List.generate(rows.length, _buildRowEditor),
          ],
        ),
      ),
    );
  }
}