// lib/features/export/export_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/network/api_client.dart';
import '../../features/sheets/models/day_sheet.dart';
import '../../features/sheets/models/trip_row.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/location/address_service.dart'; // <--- A Tisztító beimportálása

class ExportService {
  final ApiClient apiClient;

  ExportService({required this.apiClient});

  Future<String?> downloadDaySheets(
      List<DaySheet> sheets, {
        String fallbackEventName = 'DaySheets',
        String fallbackDriverName = 'Driver',
        bool isSilentShare = false,
      }) async {
    final url = Uri.parse('${apiClient.baseUrl}/export');

    final prefs = await SharedPreferences.getInstance();
    final showCity = prefs.getBool('show_city_in_trips') ?? true;

    // --- BIZTONSÁGI TISZTÍTÁS EXPORT ELŐTT ---
    final cleanSheets = sheets.map((sheet) {
      final cleanRows = sheet.rows.map((row) => TripRow(
        // Ráküldjük az exportálandó adatokat a tisztítóra, hogy garantáltan tökéletes legyen az Excel!
        departurePlace: AddressCleaner.clean(row.departurePlace, showCity),
        departureTime: row.departureTime,
        arrivalPlace: AddressCleaner.clean(row.arrivalPlace, showCity),
        arrivalTime: row.arrivalTime,
        km: row.km,
      )).toList();

      return DaySheet(
        id: sheet.id,
        vehicleType: sheet.vehicleType,
        fuelType: sheet.fuelType,
        date: sheet.date,
        carNumber: sheet.carNumber,
        driverName: sheet.driverName,
        eventName: sheet.eventName,
        isArchived: sheet.isArchived,
        rows: cleanRows,
      );
    }).toList();

    final bodyData = jsonEncode(cleanSheets.map((s) => s.toJson()).toList());

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: bodyData,
    );

    if (response.statusCode == 200) {
      final now = DateTime.now();
      String eventName = fallbackEventName;
      String driverName = fallbackDriverName;

      if (cleanSheets.isNotEmpty) {
        if (cleanSheets.first.eventName.trim().isNotEmpty) eventName = cleanSheets.first.eventName;
        if (cleanSheets.first.driverName.trim().isNotEmpty) driverName = cleanSheets.first.driverName;
      }

      final cleanEvent = eventName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final cleanDriver = driverName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final fileName = '${cleanEvent}_${cleanDriver}_${now.year}';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName.xlsx');
      await tempFile.writeAsBytes(response.bodyBytes);

      if (isSilentShare) {
        return tempFile.path;
      }

      final savedPublicPath = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: response.bodyBytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (savedPublicPath == null || savedPublicPath.trim().isEmpty) return null;

      return tempFile.path;
    } else {
      throw Exception('${tr('err_server_error')}: ${response.statusCode} - ${response.body}');
    }
  }
}