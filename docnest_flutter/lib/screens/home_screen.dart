import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/quick_actions_bar.dart';
import '../widgets/document_section.dart';
import '../widgets/profile_tab.dart';
import '../widgets/settings_tab.dart';
import './login_screen.dart';
import '../providers/document_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final Map<String, List<Document>> _documentSections = {
    'Educational Documents': [
      Document(
        id: 'edu1',
        name: 'Transcript',
        content: 'Academic transcript details',
        category: 'Educational',
        createdAt: DateTime.parse('2024-03-15'),
        modifiedAt: DateTime.parse('2024-03-15'),
      ),
      Document(
        id: 'edu2',
        name: 'Degree Certificate',
        content: 'Degree certificate details',
        category: 'Educational',
        createdAt: DateTime.parse('2024-03-10'),
        modifiedAt: DateTime.parse('2024-03-10'),
      ),
    ],
    'Government Documents': [
      Document(
        id: 'gov1',
        name: 'Passport',
        content: 'Passport details',
        category: 'Government',
        createdAt: DateTime.parse('2024-03-08'),
        modifiedAt: DateTime.parse('2024-03-08'),
      ),
      Document(
        id: 'gov2',
        name: 'Driver License',
        content: 'Driver license details',
        category: 'Government',
        createdAt: DateTime.parse('2024-03-05'),
        modifiedAt: DateTime.parse('2024-03-05'),
      ),
    ],
    'Medical Documents': [
      Document(
        id: 'med1',
        name: 'Health Insurance',
        content: 'Health insurance policy details',
        category: 'Medical',
        createdAt: DateTime.parse('2024-03-01'),
        modifiedAt: DateTime.parse('2024-03-01'),
      ),
      Document(
        id: 'med2',
        name: 'Medical Report',
        content: 'Medical report details',
        category: 'Medical',
        createdAt: DateTime.parse('2024-02-28'),
        modifiedAt: DateTime.parse('2024-02-28'),
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    // Load all documents into the DocumentProvider
    Future.microtask(() {
      final documentProvider = context.read<DocumentProvider>();
      _documentSections.values.forEach((documents) {
        documents.forEach((doc) => documentProvider.addDocument(doc));
      });
    });
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return Column(
          children: [
            const QuickActionsBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _documentSections.entries.map((section) {
                  return DocumentSection(
                    title: section.key,
                    documents: section.value,
                  );
                }).toList(),
              ),
            ),
          ],
        );
      case 1:
        return const ProfileTab();
      case 2:
        return SettingsTab(
          onLogout: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          },
        );
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DocNest',
          style: TextStyle(fontFamily: 'Helvetica'),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text(
                "User Name",
                style: TextStyle(fontFamily: 'Helvetica'),
              ),
              accountEmail: const Text(
                "user@example.com",
                style: TextStyle(fontFamily: 'Helvetica'),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: const Text("UN"),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text(
                'Government Documents',
                style: TextStyle(fontFamily: 'Helvetica'),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital),
              title: const Text(
                'Medical Documents',
                style: TextStyle(fontFamily: 'Helvetica'),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text(
                'Educational Documents',
                style: TextStyle(fontFamily: 'Helvetica'),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
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
