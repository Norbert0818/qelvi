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

  // Modern input decoration helper
  InputDecoration _modernInput(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.blue.shade700),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
    );
  }

  Widget _buildRowEditor(int index) {
    final row = rows[index];

    final departurePlaceController = TextEditingController(text: row.departurePlace);
    final departureTimeController = TextEditingController(text: row.departureTime);
    final arrivalPlaceController = TextEditingController(text: row.arrivalPlace);
    final arrivalTimeController = TextEditingController(text: row.arrivalTime);
    final kmController = TextEditingController(text: row.km == 0 ? '' : row.km.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.route, size: 18, color: Colors.blue.shade700),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Trip #${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      rows.removeAt(index);
                    });
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Delete row',
                ),
              ],
            ),
            const Divider(height: 24),

            // Departure Info
            TextField(
              controller: departurePlaceController,
              decoration: _modernInput('Departure place', Icons.my_location),
              onChanged: (value) => row.departurePlace = value,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: departureTimeController,
              decoration: _modernInput('Departure time', Icons.access_time),
              onChanged: (value) => row.departureTime = value,
            ),
            const SizedBox(height: 12),

            // Arrival Info
            TextField(
              controller: arrivalPlaceController,
              decoration: _modernInput('Arrival place', Icons.location_on),
              onChanged: (value) => row.arrivalPlace = value,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: arrivalTimeController,
              decoration: _modernInput('Arrival time', Icons.access_time_filled),
              onChanged: (value) => row.arrivalTime = value,
            ),
            const SizedBox(height: 12),

            // KM Info
            TextField(
              controller: kmController,
              decoration: _modernInput('KM', Icons.directions_car),
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
      backgroundColor: Colors.grey.shade50,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Trip rows - ${widget.daySheet.date}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRow,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add),
        label: const Text('Add row', style: TextStyle(fontWeight: FontWeight.bold)),
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_road, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No trip rows for this day yet.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ...List.generate(rows.length, _buildRowEditor),
          ],
        ),
      ),
    );
  }
}