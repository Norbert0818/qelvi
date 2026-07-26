// lib/features/sheets/models/day_sheet.dart
import 'trip_row.dart';

class DaySheet {
  int id;
  String vehicleType;
  String fuelType;
  String date;
  String carNumber;
  String driverName;
  String eventName;
  int startingOdometer; // <--- Itt a kilométeróra állás
  bool isArchived;
  List<TripRow> rows;

  DaySheet({
    required this.id,
    required this.vehicleType,
    required this.fuelType,
    required this.date,
    required this.carNumber,
    required this.driverName,
    required this.eventName,
    this.startingOdometer = 0,
    this.isArchived = false,
    required this.rows,
  });

  double get totalKm => rows.fold(0.0, (sum, row) => sum + row.km);

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleType': vehicleType,
    'fuelType': fuelType,
    'date': date,
    'carNumber': carNumber,
    'driverName': driverName,
    'eventName': eventName,
    'startingOdometer': startingOdometer,
    'isArchived': isArchived,
    'rows': rows.map((e) => e.toJson()).toList(),
  };

  factory DaySheet.fromJson(Map json) {
    return DaySheet(
      id: json['id'],
      vehicleType: json['vehicleType'] ?? '',
      fuelType: json['fuelType'] ?? '',
      date: json['date'] ?? '',
      carNumber: json['carNumber'] ?? '',
      driverName: json['driverName'] ?? '',
      eventName: json['eventName'] ?? '',
      startingOdometer:
      (json['startingOdometer'] as num?)?.toInt() ??
          int.tryParse(json['startingOdometer']?.toString() ?? '') ??
          0,
      isArchived: json['isArchived'] ?? false,
      rows: ((json['rows'] as List?) ?? [])
          .map((e) => TripRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}