// lib/features/export/export_service.dart
import 'dart:convert';
import 'dart:io'; // <-- Új import a fájlkezeléshez
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart'; // <-- Új import az átmeneti mappához
import '../../core/network/api_client.dart';
import '../../features/sheets/models/day_sheet.dart';
import 'package:easy_localization/easy_localization.dart';

class ExportService {
  final ApiClient apiClient;

  ExportService({required this.apiClient});

  Future<String?> downloadDaySheets(
      List<DaySheet> sheets, {
        String fallbackEventName = 'DaySheets',
        String fallbackDriverName = 'Driver',
      }) async {
    final url = Uri.parse('${apiClient.baseUrl}/export');

    final bodyData = jsonEncode(sheets.map((s) => s.toJson()).toList());

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: bodyData,
    );

    if (response.statusCode == 200) {
      final now = DateTime.now();
      final yearStr = now.year.toString();

      String eventName = fallbackEventName;
      String driverName = fallbackDriverName;

      if (sheets.isNotEmpty) {
        if (sheets.first.eventName.trim().isNotEmpty) {
          eventName = sheets.first.eventName;
        }
        if (sheets.first.driverName.trim().isNotEmpty) {
          driverName = sheets.first.driverName;
        }
      }

      final cleanEvent = eventName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final cleanDriver = driverName.replaceAll(RegExp(r'[^\w\s-]'), '_');

      final fileName = '${cleanEvent}_${cleanDriver}_$yearStr';

      // 1. Lementjük a telefon nyilvános tárhelyére (hogy meglegyen a felhasználónak)
      final savedPublicPath = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: response.bodyBytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      // Ha a felhasználó rányomott a Mégse gombra, kilépünk
      if (savedPublicPath == null || savedPublicPath.trim().isEmpty) {
        return null;
      }

      // 2. A BIZTOS MEGNYITÁSHOZ: Kimentjük az alkalmazás saját belső mappájába is!
      // A Google Sheets kizárólag innen tudja jogosultságcsapda nélkül megnyitni.
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName.xlsx');
      await tempFile.writeAsBytes(response.bodyBytes);

      // Visszaadjuk a belső, garantáltan nyitható fájl útvonalát az OpenFilex-nek!
      return tempFile.path;
    } else {
      throw Exception('${tr('err_server_error')}: ${response.statusCode} - ${response.body}');
    }
  }
}