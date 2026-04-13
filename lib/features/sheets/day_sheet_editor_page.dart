import 'package:flutter/material.dart';
import 'models/day_sheet.dart';
import 'day_sheet_details_page.dart';
import 'trip_rows_editor_page.dart';

class DaySheetEditorPage extends StatefulWidget {
  final DaySheet daySheet;
  final List<DaySheet> allSheets;
  final ValueChanged<DaySheet> onSave;

  const DaySheetEditorPage({
    super.key,
    required this.daySheet,
    required this.allSheets,
    required this.onSave,
  });

  @override
  State<DaySheetEditorPage> createState() => _DaySheetEditorPageState();
}

class _DaySheetEditorPageState extends State<DaySheetEditorPage> {
  late DaySheet sheet;

  @override
  void initState() {
    super.initState();
    sheet = widget.daySheet;
  }

  Future<void> _openDetails() async {
    final updated = await Navigator.push<DaySheet>(
      context,
      MaterialPageRoute(
        builder: (_) => DaySheetDetailsPage(daySheet: sheet),
      ),
    );

    if (updated != null) {
      setState(() {
        sheet = updated;
      });
    }
  }

  Future<void> _openRows() async {
    final updated = await Navigator.push<DaySheet>(
      context,
      MaterialPageRoute(
        builder: (_) => TripRowsEditorPage(daySheet: sheet),
      ),
    );

    if (updated != null) {
      setState(() {
        sheet = updated;
      });
    }
  }

  Future<void> _pickDate() async {
    final current = _parseDate(sheet.date) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (picked == null) return;

    final newDate = _formatDate(picked);
    final existing = _findSheetByDate(newDate);

    setState(() {
      sheet = existing ??
          DaySheet(
            id: DateTime.now().millisecondsSinceEpoch,
            vehicleType: sheet.vehicleType,
            fuelType: sheet.fuelType,
            date: newDate,
            carNumber: sheet.carNumber,
            driverName: sheet.driverName,
            eventName: sheet.eventName,
            rows: [],
          );
    });
  }

  DaySheet? _findSheetByDate(String date) {
    try {
      return widget.allSheets.firstWhere((e) => e.date == date);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    return '$dd.$mm.$yyyy';
  }

  DateTime? _parseDate(String raw) {
    try {
      final parts = raw.split('.');
      if (parts.length != 3) return null;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  void _save() {
    widget.onSave(sheet);
    Navigator.pop(context);
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date'),
                subtitle: Text(sheet.date.isEmpty ? 'Select date' : sheet.date),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Details'),
                subtitle: Text(
                  '${sheet.vehicleType} • ${sheet.fuelType}\n${sheet.carNumber} • ${sheet.driverName}',
                ),
                isThreeLine: true,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.route_outlined),
                title: const Text('Trip rows'),
                subtitle: Text(
                  '${sheet.rows.length} rows • ${sheet.totalKm.toStringAsFixed(2)} km total',
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openDetails,
              icon: const Icon(Icons.edit_note),
              label: const Text('Edit details'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openRows,
              icon: const Icon(Icons.route_outlined),
              label: const Text('Edit trip rows'),
            ),
          ],
        ),
      ),
    );
  }
}