// import 'dart:convert';
// import 'dart:io';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';
//
// import '../../core/network/api_client.dart';
// import '../../features/sheets/models/day_sheet.dart';
//
// class ExportService {
//   final ApiClient apiClient;
//
//   ExportService({required this.apiClient});
//
//   // 1. Adatok küldése a Python backendnek és a fájl letöltése
//   Future<File> exportDaySheets(List<DaySheet> sheets) async {
//     // Összeállítjuk az URL-t (a settingsből jön)
//     final url = Uri.parse('${apiClient.baseUrl}/export');
//
//     // JSON formátumra alakítjuk az app adatait
//     final bodyData = jsonEncode(sheets.map((s) => s.toJson()).toList());
//
//     final response = await http.post(
//       url,
//       headers: {'Content-Type': 'application/json'},
//       body: bodyData,
//     );
//
//     if (response.statusCode == 200) {
//       // Sikeres kérés! Lementjük a megkapott .xlsx fájlt a telefon ideiglenes mappájába.
//       final directory = await getTemporaryDirectory();
//
//       // Mai dátummal formázzuk a fájl nevét
//       final now = DateTime.now();
//       final dateStr = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
//
//       final file = File('${directory.path}/Utnilvantartas_$dateStr.xlsx');
//
//       await file.writeAsBytes(response.bodyBytes);
//       return file;
//     } else {
//       throw Exception('Failed to export: ${response.statusCode} - ${response.body}');
//     }
//   }
//
//   // 2. A letöltött fájl megosztása (WhatsApp, Email, stb.)
//   Future<void> shareExportedFile(File file) async {
//     if (!await file.exists()) {
//       throw Exception("A fájl nem található a megosztáshoz.");
//     }
//
//     // A share_plus csomaggal megnyitjuk a telefon natív megosztó ablakát
//     await Share.shareXFiles(
//       [XFile(file.path)],
//       text: 'Napi útnyilvántartás export',
//     );
//   }
// }

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import '../../core/network/api_client.dart';
import '../../features/sheets/models/day_sheet.dart';

class ExportService {
  final ApiClient apiClient;

  ExportService({required this.apiClient});


  // Most már nem ad vissza File-t, mert egyből lementi a telefonra
  Future<void> downloadDaySheets(List<DaySheet> sheets) async {
    final url = Uri.parse('${apiClient.baseUrl}/export'); // Vagy a sima baseUrl, attól függ hogy adtad meg a .env-ben

    final bodyData = jsonEncode(sheets.map((s) => s.toJson()).toList());

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: bodyData,
    );

    if (response.statusCode == 200) {
      // Mai dátum a fájlnévhez
      final now = DateTime.now();
      final dateStr = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
      final fileName = 'Utnyilvantartas_$dateStr';

      // Ez a varázslat: Lementi a fájlt a telefon "Letöltések" (Downloads) mappájába!
      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: response.bodyBytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    } else {
      throw Exception('Szerver hiba: ${response.statusCode} - ${response.body}');
    }
  }
}