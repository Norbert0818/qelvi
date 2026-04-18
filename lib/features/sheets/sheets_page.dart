import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'models/trip_row.dart';

class SheetsPage extends StatefulWidget {
  const SheetsPage({super.key});

  @override
  State<SheetsPage> createState() => _SheetsPageState();
}

class _SheetsPageState extends State<SheetsPage> {
  final _prefs = PrefsService();

  List<DaySheet> sheets = [];

  // Initialize with fallback values
  SettingsModel settings = const SettingsModel(
    apiBaseUrl: '',
    apiKey: '',
    defaultDriverName: '',
    defaultCarPlate: '',
    activeEventName: 'Qelvi',
    defaultFuelType: 'Motorină',
    defaultVehicleType: 'Persoane',
  );

  int selectedTab = 0;
  bool loading = true;

  // --- Tracking Variables ---
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

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final loadedSheets = await _prefs.loadDaySheets();
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      sheets = loadedSheets;
      // Load both the API keys and the default profile data
      settings = SettingsModel(
        apiBaseUrl: Env.apiBaseUrl,
        apiKey: Env.apiKey,
        defaultDriverName: prefs.getString('default_driver_name') ?? '',
        defaultCarPlate: prefs.getString('default_car_number') ?? '',
        activeEventName: prefs.getString('active_event_name') ?? 'Qelvi',
        defaultFuelType: prefs.getString('default_fuel_type') ?? 'Motorină',
        defaultVehicleType: prefs.getString('default_vehicle_type') ?? 'Persoane',
      );
      loading = false;
    });
  }

  Future<void> _saveSheets() async {
    await _prefs.saveDaySheets(sheets);
    setState(() {});
  }

  // --- Tracking Logic ---
  void _onTaskData(Object data) {
    if (data is Map) {
      if (data['type'] == 'update') {
        // Ensure UI updates by calling setState
        setState(() {
          tracking = tracking.copyWith(
            isTracking: true, // Force it to show as tracking
            // Use dynamic parsing to safely handle the numbers
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
    try {
      final result = await _trackingService.startTrip();

      if (!mounted) return;
      setState(() {
        tracking = result.snapshot;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracking started.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Start error: $e')),
      );
    }
  }

  Future<void> _stopTracking() async {
    try {
      // We now use the smart stop function from tracking_service
      // which automatically handles finding/creating the DaySheet!
      final result = await _trackingService.stopAndSaveTrip();

      if (!mounted) return;

      setState(() {
        tracking = result.snapshot;
      });

      // Reload the data from memory so the newly created row appears instantly
      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracking stopped and saved successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stop error: $e')),
      );
    }
  }

  void _openEditor([DaySheet? existing]) {
    final now = DateTime.now();
    final todayStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    // When creating a new manual sheet, use the settings defaults!
    final daySheet = existing ??
        DaySheet(
          id: DateTime.now().millisecondsSinceEpoch,
          vehicleType: settings.defaultVehicleType,
          fuelType: settings.defaultFuelType,
          date: todayStr,
          carNumber: settings.defaultCarPlate,
          driverName: settings.defaultDriverName,
          eventName: settings.activeEventName,
          rows: [],
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DaySheetEditorPage(
          daySheet: daySheet,
          allSheets: sheets,
          onSave: (updated) async {
            final indexById = sheets.indexWhere((e) => e.id == updated.id);
            final indexByDate = sheets.indexWhere((e) => e.date == updated.date);

            if (indexById >= 0) {
              sheets[indexById] = updated;
            } else if (indexByDate >= 0) {
              sheets[indexByDate] = updated;
            } else {
              sheets.insert(0, updated);
            }

            await _saveSheets();
          },
        ),
      ),
    );
  }

  Future<void> _deleteSheet(DaySheet sheet) async {
    sheets.removeWhere((e) => e.id == sheet.id);
    await _saveSheets();
  }

  Future<void> _archiveCurrentEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive event: ${settings.activeEventName}?'),
        content: const Text(
          'All sheets belonging to this event will be hidden from the main screen, '
              'but they will be kept safely in the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      for (var sheet in sheets) {
        if (sheet.eventName == settings.activeEventName) {
          sheet.isArchived = true;
        }
      }
    });

    await _saveSheets();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${settings.activeEventName} successfully archived!')),
    );
  }

  Future<void> _export() async {
    if (settings.apiBaseUrl.isEmpty || settings.apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure API settings first.')),
      );
      setState(() {
        selectedTab = 1; // Switch to settings tab
      });
      return;
    }

    try {
      final apiClient = ApiClient(
        baseUrl: settings.apiBaseUrl,
        apiKey: settings.apiKey,
      );

      final exportService = ExportService(apiClient: apiClient);

      // Pass only the non-archived sheets for the active event to the export
      final activeSheets = sheets.where((s) => !s.isArchived && s.eventName == settings.activeEventName).toList();

      await exportService.downloadDaySheets(activeSheets);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download successful! Check your Downloads folder.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download error: $e')),
      );
    }
  }

  Widget _buildSheetsTab() {
    // ONLY show sheets that are NOT archived AND belong to the active event
    final activeSheets = sheets.where((s) =>
    !s.isArchived && s.eventName == settings.activeEventName
    ).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- TRACKING CARD ---
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 24),
          color: tracking.isTracking ? Colors.blue.shade50 : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      tracking.isTracking ? Icons.directions_car : Icons.local_parking,
                      color: tracking.isTracking ? Colors.blue : Colors.grey,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tracking.isTracking ? 'Trip in progress...' : 'Ready to drive',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Distance', style: TextStyle(color: Colors.grey)),
                        Text(
                          '${tracking.distanceKm.toStringAsFixed(2)} km',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Time', style: TextStyle(color: Colors.grey)),
                        Text(
                          tracking.elapsed,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: tracking.isTracking ? null : _startTracking,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('START'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: tracking.isTracking ? _stopTracking : null,
                        icon: const Icon(Icons.stop),
                        label: const Text('STOP'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // --- HEADER AND BUTTONS ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                settings.activeEventName.isEmpty ? 'Day sheets' : settings.activeEventName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'add') _openEditor();
                if (value == 'archive') _archiveCurrentEvent();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add',
                  child: Row(children: [Icon(Icons.add), SizedBox(width: 8), Text('Add Manual')]),
                ),
                const PopupMenuItem(
                  value: 'archive',
                  child: Row(children: [Icon(Icons.archive_outlined), SizedBox(width: 8), Text('Archive Event')]),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _export,
          icon: const Icon(Icons.download),
          label: const Text('Export Excel (Active Event)'),
        ),
        const SizedBox(height: 16),

        // Show empty message if activeSheets is empty
        if (activeSheets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 50),
            child: Center(child: Text('No sheets found for this event.')),
          ),

        // Map over activeSheets instead of all sheets
        ...activeSheets.map(
              (sheet) => Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sheet.date.isEmpty ? 'No date' : sheet.date,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openEditor(sheet),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () => _deleteSheet(sheet),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  Text('Vehicle type: ${sheet.vehicleType}'),
                  Text('Fuel type: ${sheet.fuelType}'),
                  Text('Car plate: ${sheet.carNumber}'),
                  Text('Driver: ${sheet.driverName}'),
                  Text('Rows: ${sheet.rows.length}'),
                  const SizedBox(height: 8),
                  Text(
                    'Daily total: ${sheet.totalKm.toStringAsFixed(2)} km',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return SettingsPage(
      settings: settings,
      onSettingsChanged: _loadData, // We pass a callback so Settings can refresh the main page when you change cars
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Qelvi'),
      ),
      body: selectedTab == 0 ? _buildSheetsTab() : _buildSettingsTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            selectedTab = index;
            // Always reload data when switching tabs to ensure settings are fresh
            if (index == 0) _loadData();
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.table_chart_outlined),
            selectedIcon: Icon(Icons.table_chart),
            label: 'Sheets',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}