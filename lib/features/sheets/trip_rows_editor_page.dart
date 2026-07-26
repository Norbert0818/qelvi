// lib/features/sheets/trip_rows_editor_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'models/day_sheet.dart';
import 'models/trip_row.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/location/address_service.dart';

class _RowWrapper {
  final Key key;
  final TripRow row;
  _RowWrapper({required this.key, required this.row});
}

class TripRowsEditorPage extends StatefulWidget {
  final DaySheet daySheet;

  const TripRowsEditorPage({
    super.key,
    required this.daySheet,
  });

  @override
  State<TripRowsEditorPage> createState() => _TripRowsEditorPageState();
}

class _TripRowsEditorPageState extends State<TripRowsEditorPage> {
  late List<_RowWrapper> wrappedRows;
  Position? _currentPosition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initEngine();

    wrappedRows = widget.daySheet.rows.map((r) {
      return _RowWrapper(
        key: UniqueKey(),
        row: TripRow(
          departurePlace: r.departurePlace,
          departureTime: r.departureTime,
          arrivalPlace: r.arrivalPlace,
          arrivalTime: r.arrivalTime,
          km: r.km,
        ),
      );
    }).toList();
  }

  Future<void> _initEngine() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        Position? pos = await Geolocator.getLastKnownPosition();
        pos ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 3));
        if (pos != null) {
          _currentPosition = pos;
        }
      }
    } catch (e) {
      print("⚠️ Init hiba: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addRow() {
    setState(() {
      wrappedRows.add(
        _RowWrapper(
          key: UniqueKey(),
          row: TripRow(departurePlace: '', departureTime: '', arrivalPlace: '', arrivalTime: '', km: 0),
        ),
      );
    });
  }

  void _save() {
    final updatedRows = wrappedRows.map((w) => w.row).toList();

    final updatedSheet = DaySheet(
      id: widget.daySheet.id,
      vehicleType: widget.daySheet.vehicleType,
      fuelType: widget.daySheet.fuelType,
      date: widget.daySheet.date,
      carNumber: widget.daySheet.carNumber,
      driverName: widget.daySheet.driverName,
      eventName: widget.daySheet.eventName,
      isArchived: widget.daySheet.isArchived,
      rows: updatedRows,
    );

    Navigator.pop(context, updatedSheet);
  }

  Future<List<String>> _getEsriSuggestions(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    String urlString = 'https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/suggest?text=${Uri.encodeComponent(q)}&countryCode=RO,HU&f=json&maxSuggestions=6';
    if (_currentPosition != null) {
      urlString += '&location=${_currentPosition!.longitude},${_currentPosition!.latitude}&distance=100000';
    }

    try {
      final response = await http.get(Uri.parse(urlString));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List suggestions = data['suggestions'] ?? [];

        // --- JAVÍTVA: A keresőben MINDIG várossal (true) adjuk vissza a javaslatokat! ---
        final cleanSuggestions = suggestions.map((s) => AddressCleaner.clean(s['text'].toString(), true)).toList();

        return cleanSuggestions.toSet().toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text('trip_rows_title'.tr(namedArgs: {'date': widget.daySheet.date}), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.tonal(onPressed: _save, style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('save'.tr())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addRow, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), icon: const Icon(Icons.add), label: Text('add_row'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
      body: SafeArea(
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + bottomSafe + 100),
          itemCount: wrappedRows.isEmpty ? 1 : wrappedRows.length,
          itemBuilder: (context, index) {
            if (wrappedRows.isEmpty) {
              return Padding(padding: const EdgeInsets.symmetric(vertical: 60), child: Center(child: Column(children: [Icon(Icons.edit_road, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('no_trip_rows_yet'.tr(), style: TextStyle(color: Colors.grey.shade600, fontSize: 16))])));
            }

            final item = wrappedRows[index];
            return _TripRowCard(
              key: item.key,
              index: index,
              row: item.row,
              onDelete: () => setState(() => wrappedRows.removeAt(index)),
              suggestionsCallback: _getEsriSuggestions,
            );
          },
        ),
      ),
    );
  }
}

class _TripRowCard extends StatefulWidget {
  final int index;
  final TripRow row;
  final VoidCallback onDelete;
  final Future<List<String>> Function(String) suggestionsCallback;

  const _TripRowCard({
    super.key,
    required this.index,
    required this.row,
    required this.onDelete,
    required this.suggestionsCallback,
  });

  @override
  State<_TripRowCard> createState() => _TripRowCardState();
}

class _TripRowCardState extends State<_TripRowCard> {
  late final TextEditingController _depPlaceCtrl;
  late final TextEditingController _depTimeCtrl;
  late final TextEditingController _arrPlaceCtrl;
  late final TextEditingController _arrTimeCtrl;
  late final TextEditingController _kmCtrl;

  @override
  void initState() {
    super.initState();
    _depPlaceCtrl = TextEditingController(text: widget.row.departurePlace);
    _depTimeCtrl = TextEditingController(text: widget.row.departureTime);
    _arrPlaceCtrl = TextEditingController(text: widget.row.arrivalPlace);
    _arrTimeCtrl = TextEditingController(text: widget.row.arrivalTime);
    _kmCtrl = TextEditingController(text: widget.row.km == 0 ? '' : widget.row.km.toString());
  }

  @override
  void dispose() {
    _depPlaceCtrl.dispose();
    _depTimeCtrl.dispose();
    _arrPlaceCtrl.dispose();
    _arrTimeCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  InputDecoration _modernInput(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.blue.shade700),
      filled: true,
      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade400, width: 2)),
    );
  }

  Future<void> _pickTime(TextEditingController ctrl, Function(String) onSave) async {
    TimeOfDay init = TimeOfDay.now();
    if (ctrl.text.contains(':')) {
      final p = ctrl.text.split(':');
      init = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    final picked = await showTimePicker(context: context, initialTime: init, builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!));
    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      ctrl.text = formatted;
      onSave(formatted);
    }
  }

  Widget _buildProTypeAhead({required String label, required IconData icon, required TextEditingController controller, required Function(String) onSaved}) {
    return TypeAheadField<String>(
      controller: controller,
      debounceDuration: const Duration(milliseconds: 300),
      suggestionsCallback: (pattern) async => await widget.suggestionsCallback(pattern),
      itemBuilder: (context, suggestion) => ListTile(visualDensity: VisualDensity.compact, leading: const Icon(Icons.location_on, color: Colors.blue, size: 18), title: Text(suggestion, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      onSelected: (suggestion) {
        controller.text = suggestion;
        onSaved(suggestion);
      },
      builder: (context, ctrl, focusNode) => TextField(controller: ctrl, focusNode: focusNode, decoration: _modernInput(label, icon), onChanged: onSaved),
      emptyBuilder: (context) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(22), border: Border.all(color: Theme.of(context).dividerColor), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: Icon(Icons.route, size: 18, color: Colors.blue.shade700)), const SizedBox(width: 12), Text('trip_number'.tr(namedArgs: {'number': (widget.index + 1).toString()}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]), IconButton(onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent), tooltip: 'delete_row_tooltip'.tr())]),
            const Divider(height: 24),
            _buildProTypeAhead(label: 'departure_place'.tr(), icon: Icons.my_location, controller: _depPlaceCtrl, onSaved: (v) => widget.row.departurePlace = v),
            const SizedBox(height: 12),
            TextField(controller: _depTimeCtrl, decoration: _modernInput('departure_time'.tr(), Icons.access_time), readOnly: true, onTap: () => _pickTime(_depTimeCtrl, (v) => widget.row.departureTime = v)),
            const SizedBox(height: 12),
            _buildProTypeAhead(label: 'arrival_place'.tr(), icon: Icons.location_on, controller: _arrPlaceCtrl, onSaved: (v) => widget.row.arrivalPlace = v),
            const SizedBox(height: 12),
            TextField(controller: _arrTimeCtrl, decoration: _modernInput('arrival_time'.tr(), Icons.access_time_filled), readOnly: true, onTap: () => _pickTime(_arrTimeCtrl, (v) => widget.row.arrivalTime = v)),
            const SizedBox(height: 12),
            TextField(controller: _kmCtrl, decoration: _modernInput('km_label'.tr(), Icons.directions_car), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => widget.row.km = double.tryParse(v.replaceAll(',', '.')) ?? 0),
          ],
        ),
      ),
    );
  }
}