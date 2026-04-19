import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_model.dart';
import '../sheets/archive_page.dart';

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

  // Választható opciók a legördülő menühöz
  final List<String> _fuelOptions = ['Motorină', 'Benzin', 'Electric', 'Hybrid'];
  final List<String> _vehicleOptions = ['Persoane', 'Marfă', 'Special'];

  @override
  void initState() {
    super.initState();
    _driverController = TextEditingController(text: widget.settings.defaultDriverName);
    _carController = TextEditingController(text: widget.settings.defaultCarPlate);
    _eventController = TextEditingController(text: widget.settings.activeEventName);

    // Biztosítjuk, hogy a meglévő beállítás szerepeljen a listában, ha nem, az első elemet kapja
    _selectedFuelType = widget.settings.defaultFuelType.isEmpty || !_fuelOptions.contains(widget.settings.defaultFuelType)
        ? _fuelOptions.first
        : widget.settings.defaultFuelType;

    _selectedVehicleType = widget.settings.defaultVehicleType.isEmpty || !_vehicleOptions.contains(widget.settings.defaultVehicleType)
        ? _vehicleOptions.first
        : widget.settings.defaultVehicleType;
  }

  @override
  void dispose() {
    _driverController.dispose();
    _carController.dispose();
    _eventController.dispose();
    super.dispose();
  }

  Future<void> _updatePref(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    widget.onSettingsChanged();
  }

  // Modern input decoration helper
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
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
                    const Text(
                      'Trip Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'These details are required before you can start tracking.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _eventController,
                  decoration: _modernInput('Active Event Name', Icons.event_available_rounded, Colors.purple.shade500),
                  onChanged: (v) => _updatePref('active_event_name', v.trim()),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _carController,
                  decoration: _modernInput('Car Plate Number', Icons.directions_car_rounded, Colors.indigo.shade500),
                  onChanged: (v) => _updatePref('default_car_number', v.trim()),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _driverController,
                  decoration: _modernInput('Driver Name', Icons.badge_rounded, Colors.teal.shade500),
                  onChanged: (v) => _updatePref('default_driver_name', v.trim()),
                ),
                const SizedBox(height: 16),

                // Jármű típus Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  decoration: _modernInput('Vehicle Type', Icons.local_shipping_rounded, Colors.brown.shade500),
                  items: _vehicleOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedVehicleType = v);
                      _updatePref('default_vehicle_type', v);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Üzemanyag típus Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedFuelType,
                  decoration: _modernInput('Fuel Type', Icons.local_gas_station_rounded, Colors.orange.shade500),
                  items: _fuelOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Open Archive',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'View and manage your history',
                              style: TextStyle(
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