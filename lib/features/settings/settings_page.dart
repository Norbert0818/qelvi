import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/widgets/section_card.dart';
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

  @override
  void initState() {
    super.initState();
    // Initialize the text fields with the current settings
    _driverController = TextEditingController(text: widget.settings.defaultDriverName);
    _carController = TextEditingController(text: widget.settings.defaultCarPlate);
    _eventController = TextEditingController(text: widget.settings.activeEventName);
  }

  @override
  void dispose() {
    _driverController.dispose();
    _carController.dispose();
    _eventController.dispose();
    super.dispose();
  }

  // Saves to memory and tells the main page to refresh
  Future<void> _updatePref(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    widget.onSettingsChanged(); // This calls _loadData() on SheetsPage
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Default Trip Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'These details will automatically fill when creating a new day sheet or starting a trip.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _eventController,
                decoration: const InputDecoration(
                  labelText: 'Active Event (e.g., Untold)',
                  prefixIcon: Icon(Icons.event),
                ),
                onChanged: (v) => _updatePref('active_event_name', v.trim()),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _carController,
                decoration: const InputDecoration(
                  labelText: 'Current Car Plate',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                onChanged: (v) => _updatePref('default_car_number', v.trim()),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _driverController,
                decoration: const InputDecoration(
                  labelText: 'Default Driver Name',
                  prefixIcon: Icon(Icons.badge),
                ),
                onChanged: (v) => _updatePref('default_driver_name', v.trim()),
              ),
            ],
          ),
        ),

        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArchivePage(
                  settings: widget.settings,
                  onDataChanged: widget.onSettingsChanged, // Frissítjük a főoldalt ha visszaállítottunk valamit
                ),
              ),
            );
          },
          icon: const Icon(Icons.history),
          label: const Text('Open Archive (History)'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.centerLeft,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}