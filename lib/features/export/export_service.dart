// lib/features/export/export_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
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
        bool isSilentShare = false, // <--- ÚJ PARAMÉTER
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
      String eventName = fallbackEventName;
      String driverName = fallbackDriverName;

      if (sheets.isNotEmpty) {
        if (sheets.first.eventName.trim().isNotEmpty) eventName = sheets.first.eventName;
        if (sheets.first.driverName.trim().isNotEmpty) driverName = sheets.first.driverName;
      }

      final cleanEvent = eventName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final cleanDriver = driverName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final fileName = '${cleanEvent}_${cleanDriver}_${now.year}';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName.xlsx');
      await tempFile.writeAsBytes(response.bodyBytes);

      // HA MEGOSZTÁS MÓDBAN VAGYUNK: Nem dobjuk fel a mentés ablakot,
      // csak visszaadjuk a csendben legenerált fájl útvonalát!
      if (isSilentShare) {
        return tempFile.path;
      }

      // HA NORMÁL EXPORT MÓDBAN VAGYUNK: Feldobjuk a mentés ablakot
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