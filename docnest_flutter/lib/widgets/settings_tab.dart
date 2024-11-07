import 'package:flutter/material.dart';

class SettingsTab extends StatelessWidget {
  final VoidCallback onLogout;

  const SettingsTab({
    super.key,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingSwitch(
          icon: Icons.notifications,
          title: 'Notifications',
          value: true,
          onChanged: (value) {
            // Handle notification toggle
          },
        ),
        _buildSettingSwitch(
          icon: Icons.dark_mode,
          title: 'Dark Mode',
          value: false,
          onChanged: (value) {
            // Handle dark mode toggle
          },
        ),
        _buildSettingOption(
          icon: Icons.language,
          title: 'Language',
          onTap: () {
            // Handle language settings
          },
        ),
        _buildSettingOption(
          icon: Icons.help,
          title: 'Help & Support',
          onTap: () {
            // Handle help and support
          },
        ),
        _buildSettingOption(
          icon: Icons.info,
          title: 'About',
          onTap: () {
            // Handle about section
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onLogout,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text(
            'Logout',
            style: TextStyle(
              fontFamily: 'Helvetica',
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontFamily: 'Helvetica'),
      ),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: onTap,
    );
  }

  Widget _buildSettingSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontFamily: 'Helvetica'),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
