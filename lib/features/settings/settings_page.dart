// lib/features/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_model.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

class SettingsPage extends StatefulWidget {
  final SettingsModel settings;
  final VoidCallback onSettingsChanged;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _driverController;
  late final TextEditingController _carController;
  late final TextEditingController _eventController;
  late final TextEditingController _odometerController; // <--- ÚJ

  String? _selectedFuelType;
  String? _selectedVehicleType;

  bool _showCityInTrips = false;

  final List<String> _fuelOptions = ['Diesel', 'Petrol', 'Electric', 'Hybrid'];
  final List<String> _vehicleOptions = ['Passenger', 'Cargo'];

  @override
  void initState() {
    super.initState();
    _driverController = TextEditingController(text: widget.settings.defaultDriverName);
    _carController = TextEditingController(text: widget.settings.defaultCarPlate);
    _eventController = TextEditingController(text: widget.settings.activeEventName);

    // <--- ÚJ: Odometer controller inicializálása
    _odometerController = TextEditingController(
        text: widget.settings.defaultStartingOdometer == 0 ? '' : widget.settings.defaultStartingOdometer.toString()
    );

    if (widget.settings.defaultFuelType.isNotEmpty && _fuelOptions.contains(widget.settings.defaultFuelType)) {
      _selectedFuelType = widget.settings.defaultFuelType;
    }

    if (widget.settings.defaultVehicleType.isNotEmpty && _vehicleOptions.contains(widget.settings.defaultVehicleType)) {
      _selectedVehicleType = widget.settings.defaultVehicleType;
    }

    _loadCitySetting();
  }

  Future<void> _loadCitySetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showCityInTrips = prefs.getBool('show_city_in_trips') ?? false;
    });
  }

  @override
  void dispose() {
    _driverController.dispose();
    _carController.dispose();
    _eventController.dispose();
    _odometerController.dispose(); // <--- ÚJ
    super.dispose();
  }

  Future<void> _updatePref(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    widget.onSettingsChanged();
  }

  // <--- ÚJ: Külön mentő függvény a számoknak
  Future<void> _updatePrefInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
    widget.onSettingsChanged();
  }

  IconData _getVehicleIcon(String? type) {
    switch (type) {
      case 'Passenger': return Icons.directions_car_rounded;
      case 'Cargo': return Icons.local_shipping_rounded;
      default: return Icons.directions_car_rounded;
    }
  }

  IconData _getFuelIcon(String? type) {
    if (type == 'Electric' || type == 'Hybrid') {
      return Icons.ev_station_rounded;
    }
    return Icons.local_gas_station_rounded;
  }

  InputDecoration _modernInput(String label, IconData icon, Color iconColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
      prefixIcon: Icon(icon, size: 22, color: iconColor),
      filled: true,
      fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.blue.shade400, width: 2)),
    );
  }

  Widget _buildLangButton(BuildContext context, String title, String langCode) {
    final isActive = context.locale.languageCode == langCode;
    return TextButton(
      onPressed: () async {
        await context.setLocale(Locale(langCode));
        widget.onSettingsChanged();
      },
      style: TextButton.styleFrom(minimumSize: const Size(40, 40), padding: EdgeInsets.zero),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
          color: isActive ? Colors.blue.shade700 : Colors.grey.shade400,
          fontSize: 15,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text('settings_title'.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        actions: [
          _buildLangButton(context, 'EN', 'en'),
          _buildLangButton(context, 'RO', 'ro'),
          _buildLangButton(context, 'HU', 'hu'),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.tune_rounded, color: Colors.blue.shade700, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('trip_details'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('trip_details_desc'.tr(), style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
                const SizedBox(height: 24),

                TextField(
                  controller: _eventController,
                  decoration: _modernInput('active_event'.tr(), Icons.event_available_rounded, Colors.purple.shade500),
                  onChanged: (v) => _updatePref('active_event_name', v.trim()),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _carController,
                  decoration: _modernInput('car_plate'.tr(), Icons.directions_car_rounded, Colors.indigo.shade500),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection)),
                  ],
                  onChanged: (v) => _updatePref('default_car_number', v.trim()),
                ),
                const SizedBox(height: 16),

                // <--- ÚJ: Alapértelmezett Kezdő Kilométer a Settings-ben
                TextField(
                  controller: _odometerController,
                  decoration: _modernInput('starting_odometer'.tr(), Icons.speed, Colors.red.shade500),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => _updatePrefInt('default_starting_odometer', int.tryParse(v) ?? 0),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _driverController,
                  decoration: _modernInput('driver_name'.tr(), Icons.badge_rounded, Colors.teal.shade500),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) => _updatePref('default_driver_name', v.trim()),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  hint: Text('select_hint'.tr()),
                  decoration: _modernInput('vehicle_type'.tr(), _getVehicleIcon(_selectedVehicleType), Colors.brown.shade500),
                  items: _vehicleOptions.map((e) => DropdownMenuItem(value: e, child: Text(e.toLowerCase().tr()))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedVehicleType = v);
                      _updatePref('default_vehicle_type', v);
                    }
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedFuelType,
                  hint: Text('select_hint'.tr()),
                  decoration: _modernInput('fuel_type'.tr(), _getFuelIcon(_selectedFuelType), Colors.orange.shade500),
                  items: _fuelOptions.map((e) => DropdownMenuItem(value: e, child: Text(e.toLowerCase().tr()))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedFuelType = v);
                      _updatePref('default_fuel_type', v);
                    }
                  },
                ),

                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('show_city_label'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('show_city_desc'.tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  activeColor: Colors.blue.shade600,
                  value: _showCityInTrips,
                  onChanged: (bool value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('show_city_in_trips', value);
                    setState(() {
                      _showCityInTrips = value;
                    });
                    widget.onSettingsChanged();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}