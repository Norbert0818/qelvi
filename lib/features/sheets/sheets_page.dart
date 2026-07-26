// lib/features/sheets/sheets_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/config/env.dart';
import '../../core/location/address_service.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/prefs_service.dart';
import '../../core/tracking/tracking_service.dart';
import '../export/export_service.dart';
import '../settings/settings_model.dart';
import '../settings/settings_page.dart';
import 'day_sheet_editor_page.dart';
import 'models/day_sheet.dart';
import 'archive_page.dart';

class SheetsPage extends StatefulWidget {
  const SheetsPage({super.key});

  @override
  State<SheetsPage> createState() => _SheetsPageState();
}

class _SheetsPageState extends State<SheetsPage> {

  DateTime _parseSheetDate(String dateStr) {
    try {
      final parts = dateStr.split('.');
      if (parts.length != 3) return DateTime(1970);
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (e) {
      return DateTime(1970);
    }
  }

  final _prefs = PrefsService();
  List<DaySheet> sheets = [];

  SettingsModel settings = const SettingsModel(
    apiBaseUrl: '',
    apiKey: '',
    defaultDriverName: '',
    defaultCarPlate: '',
    activeEventName: '',
    defaultFuelType: '',
    defaultVehicleType: '',
    defaultStartingOdometer: 0,
  );

  int selectedTab = 0;
  bool loading = true;

  late final TrackingService _trackingService;
  TrackingSnapshot tracking = TrackingSnapshot.empty();

  @override
  void initState() {
    super.initState();
    _trackingService = TrackingService(AddressService());
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);

    _loadData().then((_) async {
      final restored = await _trackingService.restoreState();
      if (mounted) {
        setState(() {
          tracking = restored;
        });
      }
    });
  }

  List<String> get _availableEvents {
    final events = sheets
        .where((s) => !s.isArchived && s.eventName.isNotEmpty)
        .map((s) => s.eventName)
        .toSet()
        .toList();

    if (settings.activeEventName.isNotEmpty && !events.contains(settings.activeEventName)) {
      events.add(settings.activeEventName);
    }

    if (events.isEmpty) {
      events.add('Day sheets');
    }

    events.sort();
    return events;
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  Future<void> _deleteCurrentEvent() async {
    final currentEvent = settings.activeEventName;
    final displayEventName = (currentEvent.isEmpty || currentEvent == 'Day sheets') ? 'day_sheets'.tr() : currentEvent;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_event_dialog_title'.tr(namedArgs: {'event': displayEventName})),
        content: Text('delete_event_dialog_desc'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete_btn'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    sheets.removeWhere((sheet) => sheet.eventName == currentEvent || (currentEvent.isEmpty && sheet.eventName.isEmpty));
    await _prefs.saveDaySheets(sheets);

    final remainingEvents = sheets
        .where((s) => !s.isArchived && s.eventName.isNotEmpty)
        .map((s) => s.eventName)
        .toSet()
        .toList();

    String nextEvent = '';
    if (remainingEvents.isNotEmpty) {
      remainingEvents.sort();
      nextEvent = remainingEvents.first;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_event_name', nextEvent);

    await _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('event_deleted_success'.tr(namedArgs: {'event': displayEventName})),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  Future<void> _loadData() async {
    final loadedSheets = await _prefs.loadDaySheets();
    final prefs = await SharedPreferences.getInstance();

    loadedSheets.sort((a, b) => _parseSheetDate(b.date).compareTo(_parseSheetDate(a.date)));

    if (mounted) {
      setState(() {
        sheets = loadedSheets;
        String fuel = prefs.getString('default_fuel_type') ?? '';
        String vehicle = prefs.getString('default_vehicle_type') ?? '';
        settings = SettingsModel(
          apiBaseUrl: Env.apiBaseUrl,
          apiKey: Env.apiKey,
          defaultDriverName: prefs.getString('default_driver_name') ?? '',
          defaultCarPlate: prefs.getString('default_car_number') ?? '',
          activeEventName: prefs.getString('active_event_name') ?? '',
          defaultFuelType: fuel,
          defaultVehicleType: vehicle,
          defaultStartingOdometer: prefs.getInt('default_starting_odometer') ?? 0,
        );
        loading = false;
      });
    }
  }

  Future<void> _saveSheets() async {
    await _prefs.saveDaySheets(sheets);
    if (mounted) {
      setState(() {});
    }
  }

  void _onTaskData(Object data) {
    if (data is Map) {
      if (data['type'] == 'update') {
        setState(() {
          tracking = tracking.copyWith(
            isTracking: true,
            distanceKm: (data['distanceKm'] is num)
                ? (data['distanceKm'] as num).toDouble()
                : tracking.distanceKm,
            elapsed: (data['elapsed'] is String)
                ? data['elapsed'] as String
                : tracking.elapsed,
          );
        });
      }
    }
  }

  Future<void> _startTracking() async {
    if (settings.defaultCarPlate.isEmpty ||
        settings.defaultDriverName.isEmpty ||
        settings.activeEventName.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('err_fill_details_start'.tr()),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        selectedTab = 2; // Beállítás fül
      });
      return;
    }

    bool hasPerms = await _trackingService.hasRequiredPermissions();

    if (!hasPerms) {
      final userAgreed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('location_disclosure_title'.tr()),
          content: Text('location_disclosure_desc'.tr()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('accept'.tr())),
          ],
        ),
      );

      if (userAgreed != true) return;
    }

    try {
      final result = await _trackingService.startTrip();

      if (!mounted) return;
      setState(() {
        tracking = result.snapshot;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('tracking_started'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('err_start_error')}: $e')),
      );
    }
  }

  Future<void> _stopTracking() async {
    try {
      final result = await _trackingService.stopAndSaveTrip();

      if (!mounted) return;

      setState(() {
        tracking = result.snapshot;
      });

      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('tracking_stopped'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('err_stop_error')}: $e')),
      );
    }
  }

  Future<void> _openEditor([DaySheet? existing]) async {
    final now = DateTime.now();
    final todayStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    DaySheet? targetSheet = existing;

    if (targetSheet == null) {
      int calculatedOdo = settings.defaultStartingOdometer;

      final todayDate = _parseSheetDate(todayStr);

      final previousCarSheets = sheets.where((s) {
        return s.carNumber == settings.defaultCarPlate &&
            _parseSheetDate(s.date).isBefore(todayDate);
      }).toList();

      previousCarSheets.sort(
            (a, b) => _parseSheetDate(b.date).compareTo(_parseSheetDate(a.date)),
      );

      if (previousCarSheets.isNotEmpty) {
        final lastSheet = previousCarSheets.first;

        if (lastSheet.startingOdometer > 0) {
          calculatedOdo = lastSheet.startingOdometer + lastSheet.totalKm.ceil();
        } else {
          calculatedOdo = settings.defaultStartingOdometer;
        }
      }

      final index = sheets.indexWhere((e) =>
      e.date == todayStr &&
          e.eventName == settings.activeEventName &&
          !e.isArchived);

      if (index >= 0) {
        final existingSheet = sheets[index];

        if (existingSheet.startingOdometer == 0) {
          targetSheet = DaySheet(
            id: existingSheet.id,
            vehicleType: existingSheet.vehicleType,
            fuelType: existingSheet.fuelType,
            date: existingSheet.date,
            carNumber: existingSheet.carNumber,
            driverName: existingSheet.driverName,
            eventName: existingSheet.eventName,
            startingOdometer: calculatedOdo,
            isArchived: existingSheet.isArchived,
            rows: existingSheet.rows,
          );

          sheets[index] = targetSheet;
          await _prefs.saveDaySheets(sheets);
        } else {
          targetSheet = existingSheet;
        }
      } else {
        targetSheet = DaySheet(
          id: DateTime.now().millisecondsSinceEpoch,
          vehicleType: settings.defaultVehicleType,
          fuelType: settings.defaultFuelType,
          date: todayStr,
          carNumber: settings.defaultCarPlate,
          driverName: settings.defaultDriverName,
          eventName: settings.activeEventName,
          startingOdometer: calculatedOdo,
          rows: [],
        );
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DaySheetEditorPage(
          daySheet: targetSheet!,
          allSheets: sheets,
          onSave: (updated) async {
            final indexById = sheets.indexWhere((e) => e.id == updated.id);

            if (indexById >= 0) {
              sheets[indexById] = updated;
            } else {
              sheets.insert(0, updated);
            }

            sheets.sort((a, b) => _parseSheetDate(b.date).compareTo(_parseSheetDate(a.date)));

            await _prefs.saveDaySheets(sheets);
          },
        ),
      ),
    );

    await _loadData();
  }

  Future<void> _deleteSheet(DaySheet sheet) async {
    sheets.removeWhere((e) => e.id == sheet.id);
    await _saveSheets();
  }

  Future<void> _archiveCurrentEvent() async {
    final currentEvent = settings.activeEventName;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('archive_event_dialog_title'.tr(namedArgs: {'event': currentEvent})),
        content: Text('archive_event_dialog_desc'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('archive_btn'.tr())),
        ],
      ),
    );

    if (confirm != true) return;

    for (var sheet in sheets) {
      if (sheet.eventName == currentEvent) {
        sheet.isArchived = true;
      }
    }
    await _prefs.saveDaySheets(sheets);

    final remainingEvents = sheets
        .where((s) => !s.isArchived && s.eventName.isNotEmpty)
        .map((s) => s.eventName)
        .toSet()
        .toList();

    String nextEvent = '';
    if (remainingEvents.isNotEmpty) {
      remainingEvents.sort();
      nextEvent = remainingEvents.first;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_event_name', nextEvent);

    await _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('event_archived_success'.tr(namedArgs: {'event': currentEvent}))),
    );
  }

  Future<void> _recalculateStartingOdometers(
      List<DaySheet> targetSheets,
      ) async {
    if (targetSheets.isEmpty) return;
    if (settings.defaultStartingOdometer <= 0) return;

    final orderedSheets = [...targetSheets];

    // Legrégebbi naptól a legújabbig
    orderedSheets.sort(
          (a, b) => _parseSheetDate(a.date).compareTo(
        _parseSheetDate(b.date),
      ),
    );

    int nextStartingOdometer = settings.defaultStartingOdometer;

    for (final sheet in orderedSheets) {
      sheet.startingOdometer = nextStartingOdometer;

      nextStartingOdometer += sheet.totalKm.ceil();

      debugPrint(
        'ODOMETER: ${sheet.date} | '
            'start=${sheet.startingOdometer} | '
            'distance=${sheet.totalKm}',
      );
    }

    // Elmentjük a frissített kilométereket
    await _prefs.saveDaySheets(sheets);
  }

  Future<void> _export() async {
    if (settings.apiBaseUrl.isEmpty || settings.apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('err_configure_api'.tr())),
      );
      setState(() {
        selectedTab = 2;
      });
      return;
    }

    try {
      final apiClient = ApiClient(baseUrl: settings.apiBaseUrl, apiKey: settings.apiKey);
      final exportService = ExportService(apiClient: apiClient);
      final activeSheets = sheets
          .where((s) =>
      !s.isArchived &&
          s.eventName == settings.activeEventName)
          .toList();

      await _recalculateStartingOdometers(activeSheets);

      for (final sheet in activeSheets) {
        debugPrint(
          'EXPORT: ${sheet.date} | '
              'startingOdometer=${sheet.startingOdometer} | '
              'totalKm=${sheet.totalKm}',
        );
      }

      final savedPath = await exportService.downloadDaySheets(
        activeSheets,
        fallbackEventName: settings.activeEventName.isNotEmpty ? settings.activeEventName : 'DaySheets',
        fallbackDriverName: settings.defaultDriverName.isNotEmpty ? settings.defaultDriverName : 'Driver',
      );

      if (savedPath == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('download_success'.tr()),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: () {
              OpenFilex.open(savedPath);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('err_download')}: $e')),
      );
    }
  }

  Future<void> _showShareDialog(List<DaySheet> activeSheets) async {
    if (activeSheets.isEmpty) return;

    final selectedSheets = await showModalBottomSheet<List<DaySheet>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DaySelectionSheet(sheets: activeSheets),
    );

    if (selectedSheets == null || selectedSheets.isEmpty) return;
    await _recalculateStartingOdometers(selectedSheets);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final apiClient = ApiClient(baseUrl: settings.apiBaseUrl, apiKey: settings.apiKey);
      final exportService = ExportService(apiClient: apiClient);

      final filePath = await exportService.downloadDaySheets(
        selectedSheets,
        fallbackEventName: settings.activeEventName.isNotEmpty ? settings.activeEventName : 'DaySheets',
        fallbackDriverName: settings.defaultDriverName.isNotEmpty ? settings.defaultDriverName : 'Driver',
        isSilentShare: true,
        // --- ÚJ: Ha nem az összes napot jelölték ki, akkor részleges formátumot kérünk! ---
        isPartial: selectedSheets.length < activeSheets.length,
      );

      if (mounted) Navigator.pop(context);

      if (filePath != null) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'share_email_subject'.tr(),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'err_generate'.tr()}: $e')),
        );
      }
    }
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildSheetsTab() {
    final activeSheets = sheets.where((s) => !s.isArchived && s.eventName == settings.activeEventName).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: tracking.isTracking ? [Colors.teal.shade400, Colors.blue.shade500] : [Colors.blue.shade600, Colors.indigo.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [BoxShadow(color: (tracking.isTracking ? Colors.teal : Colors.blue).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: Icon(tracking.isTracking ? Icons.satellite_alt : Icons.local_parking, color: Colors.white, size: 24)),
                        const SizedBox(width: 12),
                        Text(tracking.isTracking ? 'tracking_active1'.tr() : 'ready_to_drive'.tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (tracking.isTracking) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('distance'.tr(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Text('${tracking.distanceKm.toStringAsFixed(2)} km', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(height: 40, width: 1, color: Colors.white.withOpacity(0.3)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('elapsed_time'.tr(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Text(tracking.elapsed, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: tracking.isTracking ? null : _startTracking,
                        icon: Icon(Icons.play_arrow_rounded, color: tracking.isTracking ? Colors.white54 : Colors.blue.shade700),
                        label: Text('start'.tr(), style: TextStyle(color: tracking.isTracking ? Colors.white54 : Colors.blue.shade700, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        style: ElevatedButton.styleFrom(backgroundColor: tracking.isTracking ? Colors.white.withOpacity(0.15) : Colors.white, disabledBackgroundColor: Colors.white.withOpacity(0.15), shadowColor: Colors.black.withOpacity(0.1), elevation: tracking.isTracking ? 0 : 8, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: tracking.isTracking ? _stopTracking : null,
                        icon: Icon(Icons.stop_rounded, color: tracking.isTracking ? Colors.redAccent : Colors.white54),
                        label: Text('stop'.tr(), style: TextStyle(color: tracking.isTracking ? Colors.redAccent : Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        style: ElevatedButton.styleFrom(backgroundColor: tracking.isTracking ? Colors.white : Colors.white.withOpacity(0.15), disabledBackgroundColor: Colors.white.withOpacity(0.15), shadowColor: Colors.black.withOpacity(0.1), elevation: tracking.isTracking ? 8 : 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('active_event_label'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  PopupMenuButton<String>(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    tooltip: 'switch_event_tooltip'.tr(),
                    onSelected: (String newEvent) async {
                      final actualEvent = (newEvent == 'day_sheets'.tr() || newEvent == 'Day sheets') ? '' : newEvent;
                      if (actualEvent != settings.activeEventName) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('active_event_name', actualEvent);
                        await _loadData();
                      }
                    },
                    itemBuilder: (context) {
                      return _availableEvents.map((eventName) {
                        final displayEventName = eventName == 'Day sheets' ? 'day_sheets'.tr() : eventName;
                        final isSelected = eventName == settings.activeEventName || (settings.activeEventName.isEmpty && eventName == 'Day sheets');
                        return PopupMenuItem<String>(
                          value: eventName,
                          child: Row(
                            children: [
                              Icon(isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400, size: 20),
                              const SizedBox(width: 12),
                              Text(displayEventName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.blue.shade900 : Colors.black87)),
                            ],
                          ),
                        );
                      }).toList();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            (settings.activeEventName.trim().isEmpty || settings.activeEventName == 'Day sheets' || settings.activeEventName == 'day_sheets'.tr()) ? 'day_sheets'.tr() : settings.activeEventName,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blue.shade600, size: 28),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface),
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                if (value == 'add') _openEditor();
                if (value == 'archive') _archiveCurrentEvent();
                if (value == 'delete') _deleteCurrentEvent();
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'add', child: Row(children: [const Icon(Icons.add_circle_outline, color: Colors.blue), const SizedBox(width: 12), Text('add_manual'.tr())])),
                PopupMenuItem(value: 'archive', child: Row(children: [const Icon(Icons.archive_outlined, color: Colors.orange), const SizedBox(width: 12), Text('archive_event'.tr())])),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_forever, color: Colors.red), const SizedBox(width: 12), Text('delete_event'.tr(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))])),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _export,
                  icon: const Icon(Icons.download_rounded),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('export_excel'.tr()),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _showShareDialog(activeSheets),
                  icon: const Icon(Icons.send_rounded),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('share_btn'.tr()),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (activeSheets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Column(children: [Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('no_sheets_found'.tr(), style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500))])),
          ),

        ...activeSheets.map((sheet) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).dividerColor), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openEditor(sheet),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.calendar_today, size: 18, color: Colors.blue.shade700)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(sheet.date.isEmpty ? 'no_date'.tr() : sheet.date, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      IconButton(onPressed: () => _openEditor(sheet), icon: Icon(Icons.edit_outlined, color: Colors.grey.shade600), tooltip: 'edit_tooltip'.tr()),
                      IconButton(onPressed: () => _deleteSheet(sheet), icon: const Icon(Icons.delete_outline, color: Colors.redAccent), tooltip: 'delete_tooltip'.tr()),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(spacing: 8, runSpacing: 8, children: [_buildBadge(Icons.directions_car, sheet.carNumber, Colors.indigo), _buildBadge(Icons.person, sheet.driverName, Colors.teal), _buildBadge(Icons.local_gas_station, sheet.fuelType, Colors.orange)]),
                            const SizedBox(height: 12),
                            Text('trips_recorded'.tr(namedArgs: {'count': sheet.rows.length.toString()}), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            children: [
                              Text('total_badge'.tr(), style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('${sheet.totalKm.ceil()}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                              const Text('km', style: TextStyle(fontSize: 12, color: Colors.blue)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return SettingsPage(
      settings: settings,
      onSettingsChanged: _loadData,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.blue.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/app_icon.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.route, color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Qelvi',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5, color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        actions: [
          if (settings.defaultCarPlate.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(width: 6, height: 12, decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(1.5))),
                  const SizedBox(width: 6),
                  Text(
                    settings.defaultCarPlate,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
            ),
        ],
      ),

      body: selectedTab == 0
          ? _buildSheetsTab()
          : selectedTab == 1
          ? ArchivePage(settings: settings, onDataChanged: _loadData)
          : _buildSettingsTab(),

      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 10,
        indicatorColor: Colors.blue.shade100,
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            selectedTab = index;
            if (index == 0 || index == 1) _loadData();
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.table_chart_outlined),
            selectedIcon: const Icon(Icons.table_chart, color: Colors.blue),
            label: 'tab_sheets'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.archive_outlined),
            selectedIcon: const Icon(Icons.archive, color: Colors.blue),
            label: 'tab_archive'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings, color: Colors.blue),
            label: 'tab_settings'.tr(),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET: A felugró ablak a napok kiválasztásához ---
class _DaySelectionSheet extends StatefulWidget {
  final List<DaySheet> sheets;
  const _DaySelectionSheet({required this.sheets});

  @override
  State<_DaySelectionSheet> createState() => _DaySelectionSheetState();
}

class _DaySelectionSheetState extends State<_DaySelectionSheet> {
  bool _selectAll = true;
  late Set<String> _selectedDates;

  @override
  void initState() {
    super.initState();
    _selectedDates = widget.sheets.map((s) => s.date).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final uniqueDates = widget.sheets.map((s) => s.date).toSet().toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('what_to_send'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            SwitchListTile(
              title: Text('send_full_event'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('sheets_count_label'.tr(namedArgs: {'count': widget.sheets.length.toString()})),
              value: _selectAll,
              activeColor: Colors.blue.shade600,
              onChanged: (val) {
                setState(() {
                  _selectAll = val;
                  if (val) {
                    _selectedDates = widget.sheets.map((s) => s.date).toSet();
                  } else {
                    _selectedDates.clear();
                  }
                });
              },
            ),
            const Divider(),

            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: uniqueDates.length,
                itemBuilder: (context, index) {
                  final date = uniqueDates[index];
                  final isSelected = _selectedDates.contains(date);
                  return CheckboxListTile(
                    title: Text(date, style: const TextStyle(fontWeight: FontWeight.w500)),
                    value: isSelected,
                    activeColor: Colors.blue.shade600,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedDates.add(date);
                        } else {
                          _selectedDates.remove(date);
                          _selectAll = false;
                        }
                        if (_selectedDates.length == uniqueDates.length) _selectAll = true;
                      });
                    },
                  );
                },
              ),
            ),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selectedDates.isEmpty ? null : () {
                      final toExport = widget.sheets.where((s) => _selectedDates.contains(s.date)).toList();
                      Navigator.pop(context, toExport);
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: Text('send_days_count_btn'.tr(namedArgs: {'count': _selectedDates.length.toString()})),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}