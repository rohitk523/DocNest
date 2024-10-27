import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

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
