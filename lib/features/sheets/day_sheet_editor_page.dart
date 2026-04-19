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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade600,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
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

  // Helper for modern action cards
  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      content,
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Edit day sheet',
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            // DATE CARD
            _buildActionCard(
              icon: Icons.calendar_month_rounded,
              iconColor: Colors.blue.shade600,
              title: 'DATE',
              content: Text(
                sheet.date.isEmpty ? 'Select date' : sheet.date,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              onTap: _pickDate,
            ),

            // DETAILS CARD
            _buildActionCard(
              icon: Icons.badge_rounded,
              iconColor: Colors.purple.shade600,
              title: 'GENERAL DETAILS',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sheet.driverName.isEmpty ? 'No driver set' : sheet.driverName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildSmallBadge(Icons.directions_car, sheet.carNumber),
                      _buildSmallBadge(Icons.category, sheet.vehicleType),
                      _buildSmallBadge(Icons.local_gas_station, sheet.fuelType),
                    ],
                  ),
                ],
              ),
              onTap: _openDetails,
            ),

            // TRIP ROWS CARD
            _buildActionCard(
              icon: Icons.edit_road_rounded,
              iconColor: Colors.teal.shade600,
              title: 'TRIP ROUTES',
              content: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${sheet.rows.length} rows recorded',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to add or edit trips',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${sheet.totalKm.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              onTap: _openRows,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallBadge(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}