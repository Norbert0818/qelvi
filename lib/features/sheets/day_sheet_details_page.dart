// lib/features/sheets/day_sheet_details_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- ÚJ: Hozzáadva a Settings eléréséhez
import 'models/day_sheet.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

class DaySheetDetailsPage extends StatefulWidget {
  final DaySheet daySheet;

  const DaySheetDetailsPage({
    super.key,
    required this.daySheet,
  });

  @override
  State<DaySheetDetailsPage> createState() => _DaySheetDetailsPageState();
}

class _DaySheetDetailsPageState extends State<DaySheetDetailsPage> {
  late TextEditingController carNumberController;
  late TextEditingController driverNameController;
  late TextEditingController eventNameController;
  late TextEditingController odometerController;

  String? _selectedFuelType;
  String? _selectedVehicleType;

  final List<String> _fuelOptions = ['Diesel', 'Petrol', 'Electric', 'Hybrid'];
  final List<String> _vehicleOptions = ['Passenger', 'Cargo'];

  @override
  void initState() {
    super.initState();
    carNumberController = TextEditingController(text: widget.daySheet.carNumber);
    driverNameController = TextEditingController(text: widget.daySheet.driverName);
    eventNameController = TextEditingController(text: widget.daySheet.eventName);

    odometerController = TextEditingController(
        text: widget.daySheet.startingOdometer == 0 ? '' : widget.daySheet.startingOdometer.toString()
    );

    // --- ÚJ LOGIKA: Ha üres a kilométer (0), azonnal behúzzuk a Settings-ből! ---
    if (widget.daySheet.startingOdometer == 0) {
      _loadDefaultOdometer();
    }

    if (_vehicleOptions.contains(widget.daySheet.vehicleType)) {
      _selectedVehicleType = widget.daySheet.vehicleType;
    }

    if (_fuelOptions.contains(widget.daySheet.fuelType)) {
      _selectedFuelType = widget.daySheet.fuelType;
    }
  }

  // Ezt a függvényt hívjuk meg, ha nincs még elmentve a napi km
  Future<void> _loadDefaultOdometer() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultOdo = prefs.getInt('default_starting_odometer') ?? 0;
    if (defaultOdo > 0 && mounted) {
      setState(() {
        odometerController.text = defaultOdo.toString();
      });
    }
  }

  @override
  void dispose() {
    carNumberController.dispose();
    driverNameController.dispose();
    eventNameController.dispose();
    odometerController.dispose();
    super.dispose();
  }

  void _save() {
    final updated = DaySheet(
      id: widget.daySheet.id,
      vehicleType: _selectedVehicleType ?? '',
      fuelType: _selectedFuelType ?? '',
      date: widget.daySheet.date,
      carNumber: carNumberController.text.trim(),
      driverName: driverNameController.text.trim(),
      eventName: eventNameController.text.trim(),
      startingOdometer: int.tryParse(odometerController.text.trim()) ?? 0,
      isArchived: widget.daySheet.isArchived,
      rows: widget.daySheet.rows,
    );

    Navigator.pop(context, updated);
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
      prefixIcon: Icon(icon, size: 22, color: iconColor),
      filled: true,
      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'edit_details'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.tonal(
              onPressed: _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('save'.tr()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 24, 16, bottomInset + bottomSafe + 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).dividerColor),
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'general_info'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: driverNameController,
                    decoration: _modernInput('driver_name'.tr(), Icons.person, Colors.teal.shade500),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: carNumberController,
                    decoration: _modernInput('car_plate'.tr(), Icons.pin, Colors.indigo.shade500),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(
                        text: newValue.text.toUpperCase(),
                        selection: newValue.selection,
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: odometerController,
                    decoration: _modernInput('starting_odometer'.tr(), Icons.speed, Colors.red.shade500),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(7),
                    ],
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedVehicleType,
                    hint: Text('select_hint'.tr()),
                    decoration: _modernInput('vehicle_type'.tr(), _getVehicleIcon(_selectedVehicleType), Colors.blue.shade500),
                    items: _vehicleOptions.map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.toLowerCase().tr())
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedVehicleType = v);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedFuelType,
                    hint: Text('select_hint'.tr()),
                    decoration: _modernInput('fuel_type'.tr(), _getFuelIcon(_selectedFuelType), Colors.orange.shade500),
                    items: _fuelOptions.map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.toLowerCase().tr())
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedFuelType = v);
                      }
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.event, size: 20, color: Colors.purple.shade700),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'event_binding'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: eventNameController,
                    readOnly: true,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    decoration: _modernInput('event_name_locked'.tr(), Icons.celebration, Colors.purple.shade400).copyWith(
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1A1A1A)
                          : Colors.grey.shade200,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('change_event_snackbar'.tr()),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.purple.shade600,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}