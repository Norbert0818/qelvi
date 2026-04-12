import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/sheets/models/day_sheet.dart';

class PrefsService {
  static const _daySheetsKey = 'day_sheets';

  Future<List<DaySheet>> loadDaySheets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_daySheetsKey) ?? [];

    return raw
        .map((e) => DaySheet.fromJson(Map<String, dynamic>.from(jsonDecode(e))))
        .toList();
  }

  Future<void> saveDaySheets(List<DaySheet> sheets) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = sheets.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_daySheetsKey, raw);
  }
}