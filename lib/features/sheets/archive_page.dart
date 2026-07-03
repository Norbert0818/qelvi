// lib/features/sheets/archive_page.dart
import 'package:flutter/material.dart';
import '../../core/storage/prefs_service.dart';
import '../../core/network/api_client.dart';
import '../export/export_service.dart';
import '../settings/settings_model.dart';
import 'models/day_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:open_filex/open_filex.dart';

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

  // Mostantól nem egy ömlesztett lista, hanem Esemény neve alapján csoportosított Map (szótár)
  Map<String, List<DaySheet>> _archivedEvents = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchivedData();
  }

  Future<void> _loadArchivedData() async {
    final allSheets = await _prefs.loadDaySheets();
    setState(() {
      final archived = allSheets.where((s) => s.isArchived).toList();

      _archivedEvents.clear();
      // Csoportosítjuk a lapokat az eventName alapján
      for (var sheet in archived) {
        final key = sheet.eventName.isEmpty ? 'Unnamed Event' : sheet.eventName;
        _archivedEvents.putIfAbsent(key, () => []).add(sheet);
      }

      _isLoading = false;
    });
  }

  // Teljes esemény (minden hozzá tartozó nap) végleges törlése
  Future<void> _deleteEvent(String eventName, int sheetCount) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('archive_delete_title'.tr()),
        content: Text('archive_delete_desc'.tr(namedArgs: {
          'event': eventName,
          'count': sheetCount.toString(),
        })),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text('delete_btn'.tr())
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final allSheets = await _prefs.loadDaySheets();
    // Eltávolítunk minden lapot, ami ehhez az eseményhez tartozik és archiválva van
    allSheets.removeWhere((e) => e.isArchived && (e.eventName == eventName || (eventName == 'Unnamed Event' && e.eventName.isEmpty)));
    await _prefs.saveDaySheets(allSheets);

    widget.onDataChanged(); // Értesítjük a főoldalt
    _loadArchivedData(); // Újratöltjük az archívumot
  }

  // Teljes esemény visszaállítása (Vissza a főoldalra)
  Future<void> _unarchiveEvent(String eventName) async {
    final allSheets = await _prefs.loadDaySheets();
    bool wasChanged = false;

    for (var sheet in allSheets) {
      if (sheet.isArchived && (sheet.eventName == eventName || (eventName == 'Unnamed Event' && sheet.eventName.isEmpty))) {
        sheet.isArchived = false;
        wasChanged = true;
      }
    }

    if (wasChanged) {
      // --- ÚJ LOGIKA: Ha jelenleg nincs aktív esemény, azonnal beállítjuk ezt ---
      final prefs = await SharedPreferences.getInstance();
      final currentActive = prefs.getString('active_event_name') ?? '';
      if (currentActive.isEmpty) {
        await prefs.setString('active_event_name', eventName == 'Unnamed Event' ? '' : eventName);
      }

      await _prefs.saveDaySheets(allSheets);
      widget.onDataChanged(); // Ettől frissül a főoldal a háttérben
      _loadArchivedData(); // Frissíti a listát

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('archive_restore_success'.tr(namedArgs: {'event': eventName})),
          backgroundColor: Colors.green.shade600,
        ),
      );
    }
  }

  Future<void> _exportArchive() async {
    if (widget.settings.apiBaseUrl.isEmpty || widget.settings.apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('err_configure_api'.tr())),
      );
      return;
    }

    if (_archivedEvents.isEmpty) return;

    try {
      final apiClient = ApiClient(baseUrl: widget.settings.apiBaseUrl, apiKey: widget.settings.apiKey);
      final exportService = ExportService(apiClient: apiClient);

      final sheetsToExport = _archivedEvents.values.expand((list) => list).toList();

      final savedPath = await exportService.downloadDaySheets(
        sheetsToExport,
        fallbackEventName: 'Archive',
        fallbackDriverName: widget.settings.defaultDriverName.isNotEmpty ? widget.settings.defaultDriverName : 'Driver',
      );

      // Ha megszakította a mentést, kilépünk
      if (savedPath == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('archive_download_success'.tr()),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: () async {
              // 1. Megpróbáljuk megnyitni KIFEJEZETT Excel MIME-típussal
              final result = await OpenFilex.open(
                savedPath,
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              );

              // 2. Ha nem sikerült megnyitni, azonnal kiírjuk a felhasználónak, hogy miért!
              if (result.type != ResultType.done) {
                if (!mounted) return;
                String errorMsg = 'Nem sikerült megnyitni a fájlt.';
                if (result.type == ResultType.noAppToOpen) {
                  errorMsg = 'Nincs olyan alkalmazás (pl. Excel, Google Táblázatok) a telefonon, ami meg tudná nyitni!';
                } else if (result.type == ResultType.permissionDenied) {
                  errorMsg = 'Nincs jogosultság a fájl megnyitásához.';
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMsg),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('err_server_error')}: $e')),
      );
    }
  }

  // Modern badge helper
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
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final eventNames = _archivedEvents.keys.toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'archive_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'export_archive_tooltip'.tr(),
            onPressed: _archivedEvents.isEmpty ? null : _exportArchive,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _archivedEvents.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'archive_empty'.tr(),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: eventNames.length,
        itemBuilder: (context, index) {
          final eventName = eventNames[index];
          final sheetsInEvent = _archivedEvents[eventName]!;

          // Kiszámoljuk az összesített adatokat erre az Eseményre
          final totalKm = sheetsInEvent.fold(0.0, (sum, sheet) => sum + sheet.totalKm);
          final totalTrips = sheetsInEvent.fold(0, (sum, sheet) => sum + sheet.rows.length);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor),
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
                  // Top row: Esemény neve és az Akciógombok
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.folder_special_rounded, color: Colors.orange.shade700, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          eventName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'restore_event_tooltip'.tr(),
                        onPressed: () => _unarchiveEvent(eventName),
                        icon: const Icon(Icons.unarchive_outlined, color: Colors.green),
                      ),
                      IconButton(
                        tooltip: 'delete_event_tooltip'.tr(),
                        onPressed: () => _deleteEvent(eventName, sheetsInEvent.length),
                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  // Content rows: Összesítés
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
                                _buildBadge(Icons.calendar_month, 'days_count_badge'.tr(namedArgs: {'count': sheetsInEvent.length.toString()}), Colors.blue),
                                _buildBadge(Icons.route, 'trips_count_badge'.tr(namedArgs: {'count': totalTrips.toString()}), Colors.teal),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Total KM box - Tizedesek nélkül (.toInt())
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
                                'total_badge'.tr(),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${totalKm.toInt()}', // <-- Kerek, egész szám
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
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