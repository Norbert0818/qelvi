import 'package:flutter/material.dart';
import '../../shared/widgets/section_card.dart';
import 'settings_model.dart';

class SettingsPage extends StatelessWidget {
  final SettingsModel settings;

  const SettingsPage({
    super.key,
    required this.settings,
  });

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
        const SectionCard(
          child: Text(
            'Backend configuration comes from the .env file. '
                'If you want to change it, edit the .env file and restart the app.',
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'need to move here the details page',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Car, Event, Car type, etc...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}