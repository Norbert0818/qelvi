import 'package:flutter/material.dart';
import '../../core/config/env.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/prefs_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
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

  void _openEditor([DaySheet? existing]) {
    final isNew = existing == null;

    final daySheet = existing ??
        DaySheet(
          id: DateTime.now().millisecondsSinceEpoch,
          vehicleType: 'Persoane',
          people: '',
          fuelType: 'Motorină',
          date: '',
          carNumber: '',
          driverName: '',
          eventName: 'Qelvi',
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
      final file = await exportService.exportDaySheets(sheets);
      await exportService.shareExportedFile(file);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel exported successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e')),
      );
    }
  }

  Widget _buildSheetsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
              label: const Text('Add'),
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