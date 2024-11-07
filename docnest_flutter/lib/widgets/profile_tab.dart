import 'package:flutter/material.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 50,
            child: Text(
              'UN',
              style: TextStyle(
                fontSize: 32,
                fontFamily: 'Helvetica',
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'User Name',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Helvetica',
            ),
          ),
        ),
        const Center(
          child: Text(
            'user@example.com',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontFamily: 'Helvetica',
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildProfileOption(
          icon: Icons.person,
          title: 'Edit Profile',
          onTap: () {
            // Handle edit profile
          },
        ),
        _buildProfileOption(
          icon: Icons.storage,
          title: 'Storage Usage',
          onTap: () {
            // Handle storage usage
          },
        ),
        _buildProfileOption(
          icon: Icons.security,
          title: 'Security',
          onTap: () {
            // Handle security settings
          },
        ),
      ],
    );
  }

  Widget _buildProfileOption({
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
}
