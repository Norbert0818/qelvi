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

  // Helper function to build small modern badges
  Widget _buildBadge(IconData icon, String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Archive (History)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export all archived sheets',
            onPressed: _archivedSheets.isEmpty ? null : _exportArchive,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _archivedSheets.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'The archive is empty.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: _archivedSheets.length,
        itemBuilder: (context, index) {
          final sheet = _archivedSheets[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                children: [
                  // Top row: Event Badge + Date + Actions
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sheet.eventName.toUpperCase(),
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sheet.date.isEmpty ? 'No date' : sheet.date,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
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
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${sheet.totalKm.toStringAsFixed(1)}',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                              ),
                              Text(
                                'km',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
          );
        },
      ),
    );
  }
}