import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Recent Documents Section
            const Text(
              'Recent Documents',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildRecentDocumentsList(),

            // Quick Actions Section
            const SizedBox(height: 24),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickActionsGrid(),
          ],
        );
      case 1:
        return _buildProfileTab();
      case 2:
        return _buildSettingsTab();
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }

// Helper widgets for Home tab
  Widget _buildRecentDocumentsList() {
    return Card(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5, // Show last 5 documents
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.description),
            title: Text('Document ${index + 1}'),
            subtitle: Text(
                'Modified: ${DateTime.now().subtract(Duration(days: index)).toString().split('.')[0]}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Handle document tap
            },
          );
        },
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final List<Map<String, dynamic>> actions = [
      {'icon': Icons.upload_file, 'label': 'Upload'},
      {'icon': Icons.search, 'label': 'Search'},
      {'icon': Icons.share, 'label': 'Share'},
      {'icon': Icons.download, 'label': 'Download'},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: actions.map((action) {
        return Card(
          child: InkWell(
            onTap: () {
              // Handle action tap
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  action['icon'] as IconData,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  action['label'] as String,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

// Profile Tab
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 50,
            child: Text('UN', style: TextStyle(fontSize: 32)),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'User Name',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const Center(
          child: Text(
            'user@example.com',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 32),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('Edit Profile'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            // Handle edit profile
          },
        ),
        ListTile(
          leading: const Icon(Icons.storage),
          title: const Text('Storage Usage'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            // Handle storage usage
          },
        ),
        ListTile(
          leading: const Icon(Icons.security),
          title: const Text('Security'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            // Handle security settings
          },
        ),
      ],
    );
  }

// Settings Tab
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('Notifications'),
          trailing: Switch(
            value: true, // Replace with actual state
            onChanged: (bool value) {
              // Handle notification toggle
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode),
          title: const Text('Dark Mode'),
          trailing: Switch(
            value: false, // Replace with actual state
            onChanged: (bool value) {
              // Handle dark mode toggle
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('Language'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            // Handle language settings
          },
        ),
        ListTile(
          leading: const Icon(Icons.help),
          title: const Text('Help & Support'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            // Handle help and support
          },
        ),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('About'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            // Handle about section
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            // Handle logout
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Logout'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DocNest'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("User Name"),
              accountEmail: const Text("user@example.com"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: const Text("UN"),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Government Documents'),
              onTap: () {
                // Navigate to government documents
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital),
              title: const Text('Medical Documents'),
              onTap: () {
                // Navigate to medical documents
              },
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Educational Documents'),
              onTap: () {
                // Navigate to educational documents
              },
            ),
          ],
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
