import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import '../../core/network/api_client.dart';
import '../../features/sheets/models/day_sheet.dart';

class ExportService {
  final ApiClient apiClient;

  ExportService({required this.apiClient});

  Future<void> downloadDaySheets(List<DaySheet> sheets) async {
    final url = Uri.parse('${apiClient.baseUrl}/export');

    final bodyData = jsonEncode(sheets.map((s) => s.toJson()).toList());

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: bodyData,
    );

    if (response.statusCode == 200) {
      final now = DateTime.now();
      final dateStr = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';

      final eventName = sheets.isNotEmpty
          ? sheets.first.eventName.replaceAll(RegExp(r'[^\w\s-]'), '_')
          : 'Export';

      final fileName = '${eventName}_$dateStr';

      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: response.bodyBytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    } else {
      // Changed to English
      throw Exception('Server error: ${response.statusCode} - ${response.body}');
    }
  }
}