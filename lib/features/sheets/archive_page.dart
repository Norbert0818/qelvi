import 'package:flutter/material.dart';
import '../../core/storage/prefs_service.dart';
import '../../core/network/api_client.dart';
import '../export/export_service.dart';
import '../settings/settings_model.dart';
import 'models/day_sheet.dart';
import 'day_sheet_editor_page.dart';

class ArchivePage extends StatefulWidget {
  final SettingsModel settings;
  final VoidCallback onDataChanged;

  const ArchivePage({
    super.key,
    required this.settings,
    required this.onDataChanged,
  });

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  final _prefs = PrefsService();
  List<DaySheet> _archivedSheets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchivedData();
  }

  Future<void> _loadArchivedData() async {
    final allSheets = await _prefs.loadDaySheets();
    setState(() {
      // Filter only the archived sheets
      _archivedSheets = allSheets.where((s) => s.isArchived).toList();
      _isLoading = false;
    });
  }

  // Delete sheet permanently from the archive
  Future<void> _deleteSheet(DaySheet sheet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanent Delete?'),
        content: const Text('This will permanently delete the sheet. This cannot be undone!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final allSheets = await _prefs.loadDaySheets();
    allSheets.removeWhere((e) => e.id == sheet.id);
    await _prefs.saveDaySheets(allSheets);

    widget.onDataChanged(); // Notify the main page that a change occurred
    _loadArchivedData(); // Reload the archive list
  }

  // Unarchive sheet (Moves it back to the main active page)
  Future<void> _unarchiveSheet(DaySheet sheet) async {
    final allSheets = await _prefs.loadDaySheets();
    final index = allSheets.indexWhere((e) => e.id == sheet.id);
    if (index >= 0) {
      allSheets[index].isArchived = false;
      await _prefs.saveDaySheets(allSheets);

      widget.onDataChanged();
      _loadArchivedData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sheet restored to the ${sheet.eventName} event!')),
      );
    }
  }

  // Export ONLY the archived sheets
  Future<void> _exportArchive() async {
    if (widget.settings.apiBaseUrl.isEmpty || widget.settings.apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure API settings first.')),
      );
      return;
    }

    if (_archivedSheets.isEmpty) return;

    try {
      final apiClient = ApiClient(baseUrl: widget.settings.apiBaseUrl, apiKey: widget.settings.apiKey);
      final exportService = ExportService(apiClient: apiClient);

      await exportService.downloadDaySheets(_archivedSheets);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Archive downloaded! Check your Downloads folder.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive (History)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export all archived sheets',
            onPressed: _archivedSheets.isEmpty ? null : _exportArchive,
          ),
        ],
      ),
      body: _archivedSheets.isEmpty
          ? const Center(child: Text('The archive is empty.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _archivedSheets.length,
        itemBuilder: (context, index) {
          final sheet = _archivedSheets[index];
          return Card(
            color: Colors.grey.shade100, // Slightly gray to indicate it is archived
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sheet.eventName.toUpperCase(),
                          style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sheet.date,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Restore to main page',
                        onPressed: () => _unarchiveSheet(sheet),
                        icon: const Icon(Icons.unarchive_outlined, color: Colors.green),
                      ),
                      IconButton(
                        tooltip: 'Permanent Delete',
                        onPressed: () => _deleteSheet(sheet),
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${sheet.carNumber} • ${sheet.driverName}'),
                  Text('Rows: ${sheet.rows.length} • Total: ${sheet.totalKm.toStringAsFixed(2)} km'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}