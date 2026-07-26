// lib/features/sheets/day_sheet_editor_page.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // Importálva a fordításhoz
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
        color: Theme.of(context).cardColor, // <-- CSERÉLVE (Volt: Colors.white)
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor), // <-- CSERÉLVE
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'edit_day_sheet_title'.tr(), // Fordítva
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            // DATE CARD
            _buildActionCard(
              icon: Icons.calendar_month_rounded,
              iconColor: Colors.blue.shade600,
              title: 'date_card_title'.tr(), // Fordítva
              content: Text(
                sheet.date.isEmpty ? 'select_date'.tr() : sheet.date, // Fordítva
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              onTap: _pickDate,
            ),

            // DETAILS CARD
            _buildActionCard(
              icon: Icons.badge_rounded,
              iconColor: Colors.purple.shade600,
              title: 'general_details_card_title'.tr(), // Fordítva
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sheet.driverName.isEmpty ? 'no_driver_set'.tr() : sheet.driverName, // Fordítva
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
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
              title: 'trip_routes_card_title'.tr(), // Fordítva
              content: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'rows_recorded'.tr(namedArgs: {'count': sheet.rows.length.toString()}), // Fordítva, paraméterezve
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'tap_to_add_edit_trips'.tr(), // Fordítva
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
                      '${sheet.totalKm.ceil()} km', // Kerekítve (tizedesek nélkül) ahogy a többi helyen
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}