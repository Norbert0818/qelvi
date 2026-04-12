import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/network/api_client.dart';
import '../../features/sheets/models/day_sheet.dart';

class ExportService {
  final ApiClient apiClient;

  ExportService({
    required this.apiClient,
  });

  Future<File> exportDaySheets(List<DaySheet> sheets) async {
    final payload = {
      'fileName': 'qelvi_export.xlsx',
      'sheets': sheets.map((sheet) {
        return {
          'vehicleType': sheet.vehicleType,
          'people': sheet.people,
          'fuelType': sheet.fuelType,
          'date': sheet.date,
          'carNumber': sheet.carNumber,
          'driverName': sheet.driverName,
          'eventName': sheet.eventName,
          'rows': sheet.rows.map((row) => row.toJson()).toList(),
        };
      }).toList(),
    };

    final response = await apiClient.postJson('/export', payload);

    if (response.statusCode != 200) {
      throw Exception(
        'Export failed: ${response.statusCode} ${response.body}',
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/qelvi_export_$timestamp.xlsx');

    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  Future<void> shareExportedFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Qelvi Excel export',
    );
  }
}