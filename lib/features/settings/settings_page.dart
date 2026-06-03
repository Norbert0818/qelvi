import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_model.dart';
import '../sheets/archive_page.dart';
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

  late String _selectedFuelType;
  late String _selectedVehicleType;

  final List<String> _fuelOptions = ['Diesel', 'Petrol', 'Electric', 'Hybrid'];

  final List<String> _vehicleOptions = ['Passenger', 'Cargo'];

  @override
  void initState() {
    super.initState();
    _driverController = TextEditingController(text: widget.settings.defaultDriverName);
    _carController = TextEditingController(text: widget.settings.defaultCarPlate);
    _eventController = TextEditingController(text: widget.settings.activeEventName);

    if (widget.settings.defaultFuelType.isEmpty) {
      _selectedFuelType = _fuelOptions.first;
      _updatePref('default_fuel_type', _selectedFuelType);
    } else {
      _selectedFuelType = widget.settings.defaultFuelType;
    }

    if (widget.settings.defaultVehicleType.isEmpty) {
      _selectedVehicleType = _vehicleOptions.first;
      _updatePref('default_vehicle_type', _selectedVehicleType);
    } else {
      _selectedVehicleType = widget.settings.defaultVehicleType;
    }
  }

  @override
  void dispose() {
    _driverController.dispose();
    _carController.dispose();
    _eventController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.activeEventName != widget.settings.activeEventName) {
      _eventController.text = widget.settings.activeEventName;
    }
  }

  Future<void> _updatePref(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    widget.onSettingsChanged();
  }

  IconData _getVehicleIcon(String type) {
    switch (type) {
      case 'Passenger': return Icons.directions_car_rounded;
      case 'Cargo': return Icons.local_shipping_rounded;
      default: return Icons.directions_car_rounded;
    }
  }

  IconData _getFuelIcon(String type) {
    if (type == 'Electric' || type == 'Hybrid') {
      return Icons.ev_station_rounded;
    }
    return Icons.local_gas_station_rounded;
  }

  InputDecoration _modernInput(String label, IconData icon, Color iconColor) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 22, color: iconColor),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
    );
  }

  Widget _buildLangButton(BuildContext context, String title, String langCode) {
    final isActive = context.locale.languageCode == langCode;
    return TextButton(
      // --- JAVÍTÁS 1: Azonnali frissítés a főoldalon! ---
      onPressed: () async {
        await context.setLocale(Locale(langCode));
        widget.onSettingsChanged(); // Ezzel szólunk a SheetsPage-nek, hogy rajzolja újra az alsó menüt is!
      },
      style: TextButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'settings_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
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
          // --- SETTINGS CARD ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.tune_rounded, color: Colors.blue.shade700, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'trip_details'.tr(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'trip_details_desc'.tr(),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                ),
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
                    TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(
                      text: newValue.text.toUpperCase(),
                      selection: newValue.selection,
                    )),
                  ],
                  onChanged: (v) => _updatePref('default_car_number', v.trim()),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _driverController,
                  decoration: _modernInput('driver_name'.tr(), Icons.badge_rounded, Colors.teal.shade500),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) => _updatePref('default_driver_name', v.trim()),
                ),
                const SizedBox(height: 16),

                // --- JAVÍTÁS 2: Jármű típus Dropdown UI fordítása ---
                DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  decoration: _modernInput('vehicle_type'.tr(), _getVehicleIcon(_selectedVehicleType), Colors.brown.shade500),
                  items: _vehicleOptions.map((e) => DropdownMenuItem(
                      value: e,
                      // Itt csak a MEGJELENÉST fordítjuk, a mentett érték (value) marad az eredeti!
                      child: Text(e.toLowerCase().tr())
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedVehicleType = v);
                      _updatePref('default_vehicle_type', v);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // --- JAVÍTÁS 3: Üzemanyag típus Dropdown UI fordítása ---
                DropdownButtonFormField<String>(
                  value: _selectedFuelType,
                  decoration: _modernInput('fuel_type'.tr(), _getFuelIcon(_selectedFuelType), Colors.orange.shade500),
                  items: _fuelOptions.map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.toLowerCase().tr()) // Szintén itt
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedFuelType = v);
                      _updatePref('default_fuel_type', v);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- ARCHIVE ACTION BUTTON ---
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArchivePage(
                        settings: widget.settings,
                        onDataChanged: widget.onSettingsChanged,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.history_rounded, color: Colors.orange.shade600, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'open_archive'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'view_history'.tr(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}