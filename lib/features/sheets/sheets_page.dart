import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

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
  SettingsModel settings = const SettingsModel(apiBaseUrl: '', apiKey: '');
  int selectedTab = 0;
  bool loading = true;

  // --- Tracking változók ---
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

    setState(() {
      sheets = loadedSheets;
      settings = SettingsModel(
        apiBaseUrl: Env.apiBaseUrl,
        apiKey: Env.apiKey,
      );
      loading = false;
    });
  }

  Future<void> _saveSheets() async {
    await _prefs.saveDaySheets(sheets);
    setState(() {});
  }

  // --- Tracking Logika ---
  void _onTaskData(Object data) {
    if (data is! Map) return;

    final m = Map<String, dynamic>.from(data);
    if (m['type'] != 'update') return;

    setState(() {
      final km = m['distanceKm'];
      final elapsed = m['elapsed'];

      if (km is num) {
        tracking = tracking.copyWith(
          isTracking: true,
          distanceKm: km.toDouble(),
        );
      }

      if (elapsed is String) {
        tracking = tracking.copyWith(
          isTracking: true,
          elapsed: elapsed,
        );
      }
    });
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
      final result = await _trackingService.stopTrip();

      if (!mounted) return;

      setState(() {
        tracking = result.snapshot;
      });

      // 1. Megnézzük mi a mai dátum (pl. 24.10.2023 formátum)
      final now = DateTime.now();
      final todayStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

      // 2. Keresünk egy lapot, aminek ez a dátuma
      int sheetIndex = sheets.indexWhere((s) => s.date == todayStr);
      DaySheet activeSheet;

      if (sheetIndex >= 0) {
        activeSheet = sheets[sheetIndex];
      } else {
        // 3. Ha nincs mai lap, létrehozunk egyet az utolsó lap adataival
        final lastSheet = sheets.isNotEmpty ? sheets.first : null;

        activeSheet = DaySheet(
          id: DateTime.now().millisecondsSinceEpoch,
          vehicleType: lastSheet?.vehicleType ?? 'Persoane',
          fuelType: lastSheet?.fuelType ?? 'Motorină',
          date: todayStr,
          carNumber: lastSheet?.carNumber ?? '',
          driverName: lastSheet?.driverName ?? '',
          eventName: lastSheet?.eventName ?? 'Qelvi',
          rows: [],
        );
        sheets.insert(0, activeSheet);
      }

      // 4. Hozzáadjuk az utat a napi laphoz
      activeSheet.rows.add(
        TripRow(
          departurePlace: result.snapshot.startAddress ?? '',
          departureTime: _formatTime(result.snapshot.startTime),
          arrivalPlace: result.snapshot.endAddress ?? '',
          arrivalTime: _formatTime(result.snapshot.endTime),
          km: result.snapshot.distanceKm,
        ),
      );

      await _saveSheets();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracking stopped and trip saved to today\'s sheet.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stop error: $e')),
      );
    }
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '';
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // --- Kézi szerkesztő nyitása ---
  void _openEditor([DaySheet? existing]) {
    final isNew = existing == null;

    // Kézi új hozzáadásnál is használjuk az utolsó adatokat és a mai dátumot
    final now = DateTime.now();
    final todayStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    final lastSheet = sheets.isNotEmpty ? sheets.first : null;

    final daySheet = existing ??
        DaySheet(
          id: DateTime.now().millisecondsSinceEpoch,
          vehicleType: lastSheet?.vehicleType ?? 'Persoane',
          fuelType: lastSheet?.fuelType ?? 'Motorină',
          date: todayStr,
          carNumber: lastSheet?.carNumber ?? '',
          driverName: lastSheet?.driverName ?? '',
          eventName: lastSheet?.eventName ?? 'Qelvi',
          rows: [
            TripRow(
              departurePlace: '',
              departureTime: '',
              arrivalPlace: '',
              arrivalTime: '',
              km: 0,
            )
          ],
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DaySheetEditorPage(
          daySheet: daySheet,
          onSave: (updated) async {
            if (isNew) {
              sheets.insert(0, updated);
            } else {
              final index = sheets.indexWhere((e) => e.id == updated.id);
              if (index >= 0) {
                sheets[index] = updated;
              }
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

  // Future<void> _export() async {
  //   if (settings.apiBaseUrl.isEmpty || settings.apiKey.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Set backend URL and API key first.')),
  //     );
  //     setState(() {
  //       selectedTab = 1;
  //     });
  //     return;
  //   }
  //
  //   try {
  //     final apiClient = ApiClient(
  //       baseUrl: settings.apiBaseUrl,
  //       apiKey: settings.apiKey,
  //     );
  //
  //     final exportService = ExportService(apiClient: apiClient);
  //     final file = await exportService.exportDaySheets(sheets);
  //     await exportService.shareExportedFile(file);
  //
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Excel exported successfully.')),
  //     );
  //   } catch (e, stackTrace) {  // <-- Írd hozzá a stackTrace-t!
  //     if (!mounted) return;
  //
  //     // EZT ADD HOZZÁ: Kőkeményen kiíratjuk a fejlesztői konzolba!
  //     print('================ EXPORT HIBA ================');
  //     print(e.toString());
  //     print(stackTrace.toString());
  //     print('=============================================');
  //
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Export error: $e'),
  //         duration: const Duration(seconds: 5), // Legyen kint 5 másodpercig
  //       ),
  //     );
  //   }
  // }

  Future<void> _export() async {
    if (settings.apiBaseUrl.isEmpty || settings.apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set backend URL and API key first.')),
      );
      setState(() {
        selectedTab = 1;
      });
      return;
    }

    try {
      final apiClient = ApiClient(
        baseUrl: settings.apiBaseUrl,
        apiKey: settings.apiKey,
      );

      final exportService = ExportService(apiClient: apiClient);

      // Itt hívjuk meg az új letöltő függvényt
      await exportService.downloadDaySheets(sheets);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sikeres letöltés! Keresd a Letöltések mappában.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba a letöltés során: $e')),
      );
    }
  }

  Widget _buildSheetsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- TRACKING KÁRTYA ---
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

        // --- CÍMSOR ÉS GOMBOK ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Day sheets',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Add Manual'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _export,
          icon: const Icon(Icons.download),
          label: const Text('Export Excel'),
        ),
        const SizedBox(height: 16),
        if (sheets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 50),
            child: Center(child: Text('No day sheets yet.')),
          ),
        ...sheets.map(
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
                  Text('Car number: ${sheet.carNumber}'),
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
    return SettingsPage(settings: settings);
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