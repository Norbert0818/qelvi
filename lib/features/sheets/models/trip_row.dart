class TripRow {
  String departurePlace;
  String departureTime;
  String arrivalPlace;
  String arrivalTime;
  double km;

  TripRow({
    required this.departurePlace,
    required this.departureTime,
    required this.arrivalPlace,
    required this.arrivalTime,
    required this.km,
  });

  Map<String, dynamic> toJson() => {
    'departurePlace': departurePlace,
    'departureTime': departureTime,
    'arrivalPlace': arrivalPlace,
    'arrivalTime': arrivalTime,
    'km': km,
  };

  factory TripRow.fromJson(Map<String, dynamic> json) {
    return TripRow(
      departurePlace: json['departurePlace'] ?? '',
      departureTime: json['departureTime'] ?? '',
      arrivalPlace: json['arrivalPlace'] ?? '',
      arrivalTime: json['arrivalTime'] ?? '',
      km: (json['km'] as num?)?.toDouble() ?? 0,
    );
  }
}