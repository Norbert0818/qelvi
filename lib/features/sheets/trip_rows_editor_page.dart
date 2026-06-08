// lib/features/sheets/trip_rows_editor_page.dart
import 'package:flutter/material.dart';
import 'models/day_sheet.dart';
import 'models/trip_row.dart';
import 'package:easy_localization/easy_localization.dart'; // Importálva a fordításhoz

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

  // --- ÚJ IDŐVÁLASZTÓ FÜGGVÉNY ---
  Future<void> _pickTime(BuildContext context, TextEditingController controller, Function(String) onTimePicked) async {
    TimeOfDay initialTime = TimeOfDay.now();
    if (controller.text.isNotEmpty && controller.text.contains(':')) {
      final parts = controller.text.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          initialTime = TimeOfDay(hour: h, minute: m);
        }
      }
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final String formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      controller.text = formattedTime;
      onTimePicked(formattedTime);
    }
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
                      'trip_number'.tr(namedArgs: {'number': (index + 1).toString()}), // Fordítva
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
                  tooltip: 'delete_row_tooltip'.tr(), // Fordítva
                ),
              ],
            ),
            const Divider(height: 24),

            // Departure Info
            TextField(
              controller: departurePlaceController,
              decoration: _modernInput('departure_place'.tr(), Icons.my_location), // Fordítva
              onChanged: (value) => row.departurePlace = value,
            ),
            const SizedBox(height: 12),

            // Departure Time
            TextField(
              controller: departureTimeController,
              decoration: _modernInput('departure_time'.tr(), Icons.access_time), // Fordítva
              readOnly: true,
              onTap: () => _pickTime(context, departureTimeController, (val) => row.departureTime = val),
            ),
            const SizedBox(height: 12),

            // Arrival Info
            TextField(
              controller: arrivalPlaceController,
              decoration: _modernInput('arrival_place'.tr(), Icons.location_on), // Fordítva
              onChanged: (value) => row.arrivalPlace = value,
            ),
            const SizedBox(height: 12),

            // Arrival Time
            TextField(
              controller: arrivalTimeController,
              decoration: _modernInput('arrival_time'.tr(), Icons.access_time_filled), // Fordítva
              readOnly: true,
              onTap: () => _pickTime(context, arrivalTimeController, (val) => row.arrivalTime = val),
            ),
            const SizedBox(height: 12),

            // KM Info
            TextField(
              controller: kmController,
              decoration: _modernInput('km_label'.tr(), Icons.directions_car), // Fordítva
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
          'trip_rows_title'.tr(namedArgs: {'date': widget.daySheet.date}), // Fordítva
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
              child: Text('save'.tr()), // Fordítva
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRow,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add),
        label: Text('add_row'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)), // Fordítva
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
                        'no_trip_rows_yet'.tr(), // Fordítva
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