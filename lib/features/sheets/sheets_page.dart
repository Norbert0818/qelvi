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

class SheetsPage extends StatefulWidget {
  const SheetsPage({super.key});

  @override
  State<SheetsPage> createState() => _SheetsPageState();
}

class _SheetsPageState extends State<SheetsPage> {
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

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final loadedSheets = await _prefs.loadDaySheets();
    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      setState(() {
        sheets = loadedSheets;
        settings = SettingsModel(
          apiBaseUrl: Env.apiBaseUrl,
          apiKey: Env.apiKey,
          defaultDriverName: prefs.getString('default_driver_name') ?? '',
          defaultCarPlate: prefs.getString('default_car_number') ?? '',
          activeEventName: prefs.getString('active_event_name') ?? '',
          defaultFuelType: prefs.getString('default_fuel_type') ?? '',
          defaultVehicleType: prefs.getString('default_vehicle_type') ?? '',
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

  // --- Tracking Logic ---
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
          content: const Text('Please fill in the missing details before starting the trip!'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        selectedTab = 1;
      });
      return;
    }

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
      final result = await _trackingService.stopAndSaveTrip();

      if (!mounted) return;

      setState(() {
        tracking = result.snapshot;
      });

      // Reload data to show the newly saved trip immediately
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

  // JAVÍTVA: Async lett, és újratölti az adatokat a bezárás után!
  Future<void> _openEditor([DaySheet? existing]) async {
    final now = DateTime.now();
    final todayStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    DaySheet? targetSheet = existing;

    // Ha új lapot akarunk nyitni, ellenőrizzük, hogy van-e már a mai napra és erre az eseményre aktív lap!
    if (targetSheet == null) {
      final index = sheets.indexWhere((e) =>
      e.date == todayStr &&
          e.eventName == settings.activeEventName &&
          !e.isArchived);

      if (index >= 0) {
        targetSheet = sheets[index]; // Szerkesszük a meglévőt!
      } else {
        targetSheet = DaySheet(
          id: DateTime.now().millisecondsSinceEpoch,
          vehicleType: settings.defaultVehicleType,
          fuelType: settings.defaultFuelType,
          date: todayStr,
          carNumber: settings.defaultCarPlate,
          driverName: settings.defaultDriverName,
          eventName: settings.activeEventName,
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
              sheets[indexById] = updated; // Csere ID alapján
            } else {
              sheets.insert(0, updated); // Új beszúrása
            }

            await _prefs.saveDaySheets(sheets);
          },
        ),
      ),
    );

    // JAVÍTVA: Miután a szerkesztő bezárult, kényszerítjük a főoldal frissítését!
    await _loadData();
  }

  Future<void> _deleteSheet(DaySheet sheet) async {
    sheets.removeWhere((e) => e.id == sheet.id);
    await _saveSheets();
  }

  // JAVÍTVA: Biztosítjuk, hogy az állapot frissüljön és újratöltsön
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

    for (var sheet in sheets) {
      if (sheet.eventName == settings.activeEventName) {
        sheet.isArchived = true;
      }
    }

    await _prefs.saveDaySheets(sheets);
    await _loadData(); // JAVÍTVA: Azonnali újratöltés és UI frissítés!

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

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetsTab() {
    final activeSheets = sheets.where((s) =>
    !s.isArchived && s.eventName == settings.activeEventName
    ).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- MODERN TRACKING CARD ---
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: tracking.isTracking
                  ? [Colors.teal.shade400, Colors.blue.shade500]
                  : [Colors.blue.shade600, Colors.indigo.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (tracking.isTracking ? Colors.teal : Colors.blue).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            tracking.isTracking ? Icons.satellite_alt : Icons.local_parking,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          tracking.isTracking ? 'Tracking active' : 'Ready to drive',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (tracking.isTracking)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DISTANCE',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${tracking.distanceKm.toStringAsFixed(2)} km',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ELAPSED TIME',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tracking.elapsed,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // --- START GOMB ---
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: tracking.isTracking ? null : _startTracking,
                        icon: Icon(
                          Icons.play_arrow_rounded,
                          color: tracking.isTracking ? Colors.white54 : Colors.blue.shade700,
                        ),
                        label: Text(
                          'START',
                          style: TextStyle(
                            color: tracking.isTracking ? Colors.white54 : Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tracking.isTracking ? Colors.white.withOpacity(0.15) : Colors.white,
                          disabledBackgroundColor: Colors.white.withOpacity(0.15),
                          shadowColor: Colors.black.withOpacity(0.1),
                          elevation: tracking.isTracking ? 0 : 8,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // --- STOP GOMB ---
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: tracking.isTracking ? _stopTracking : null,
                        icon: Icon(
                          Icons.stop_rounded,
                          color: tracking.isTracking ? Colors.redAccent : Colors.white54,
                        ),
                        label: Text(
                          'STOP',
                          style: TextStyle(
                            color: tracking.isTracking ? Colors.redAccent : Colors.white54,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tracking.isTracking ? Colors.white : Colors.white.withOpacity(0.15),
                          disabledBackgroundColor: Colors.white.withOpacity(0.15),
                          shadowColor: Colors.black.withOpacity(0.1),
                          elevation: tracking.isTracking ? 8 : 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // --- HEADER AND EXPORT BUTTON ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Event',
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    settings.activeEventName.isEmpty ? 'Day sheets' : settings.activeEventName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black87),
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                if (value == 'add') _openEditor();
                if (value == 'archive') _archiveCurrentEvent();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add',
                  child: Row(children: [Icon(Icons.add_circle_outline, color: Colors.blue), SizedBox(width: 12), Text('Add Manual')]),
                ),
                const PopupMenuItem(
                  value: 'archive',
                  child: Row(children: [Icon(Icons.archive_outlined, color: Colors.orange), SizedBox(width: 12), Text('Archive Event')]),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _export,
          icon: const Icon(Icons.download_rounded),
          label: const Text('Export Active Event to Excel'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green.shade50,
            foregroundColor: Colors.green.shade700,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),

        // Show empty message if activeSheets is empty
        if (activeSheets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No sheets found for this event.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

        // --- MODERN LIST ITEMS ---
        ...activeSheets.map(
              (sheet) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openEditor(sheet),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Top row: Date and Actions
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.calendar_today, size: 18, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 12),
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
                          icon: Icon(Icons.edit_outlined, color: Colors.grey.shade600),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: () => _deleteSheet(sheet),
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    // Content rows
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildBadge(Icons.directions_car, sheet.carNumber, Colors.indigo),
                                  _buildBadge(Icons.person, sheet.driverName, Colors.teal),
                                  _buildBadge(Icons.local_gas_station, sheet.fuelType, Colors.orange),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${sheet.rows.length} trips recorded',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        // Total KM box
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${sheet.totalKm.toStringAsFixed(1)}',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                ),
                                const Text(
                                  'km',
                                  style: TextStyle(fontSize: 12, color: Colors.blue),
                                ),
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
          ),
        ),
        const SizedBox(height: 20), // Bottom padding
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
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Soft background for the whole app
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Qelvi',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5),
        ),
        centerTitle: false,
      ),
      body: selectedTab == 0 ? _buildSheetsTab() : _buildSettingsTab(),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        elevation: 10,
        indicatorColor: Colors.blue.shade100,
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            selectedTab = index;
            if (index == 0) _loadData();
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.table_chart_outlined),
            selectedIcon: Icon(Icons.table_chart, color: Colors.blue),
            label: 'Sheets',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Colors.blue),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}