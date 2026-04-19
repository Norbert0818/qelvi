class SettingsModel {
  final String apiBaseUrl;
  final String apiKey;
  final String defaultDriverName;
  final String defaultCarPlate;
  final String activeEventName;
  final String defaultFuelType;
  final String defaultVehicleType;

  const SettingsModel({
    required this.apiBaseUrl,
    required this.apiKey,
    this.defaultDriverName = '',
    this.defaultCarPlate = '',
    this.activeEventName = '',
    this.defaultFuelType = '',
    this.defaultVehicleType = '',
  });
}