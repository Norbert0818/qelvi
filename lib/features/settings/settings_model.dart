class SettingsModel {
  final String apiBaseUrl;
  final String apiKey;
  // Új mezők az automatikus kitöltéshez
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
    this.activeEventName = 'Untold',
    this.defaultFuelType = 'Motorină',
    this.defaultVehicleType = 'Persoane',
  });
}