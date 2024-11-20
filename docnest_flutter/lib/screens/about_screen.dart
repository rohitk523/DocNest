import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Privacy Policy',
                style: AppTextStyles.headline2,
              ),
              const SizedBox(height: 16),
              FutureBuilder(
                future: _loadPrivacyPolicy(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasData) {
                    return Text(
                      snapshot.data as String,
                      style: AppTextStyles.body1,
                    );
                  } else {
                    return Text(
                      'Failed to load privacy policy',
                      style: AppTextStyles.body1.copyWith(color: Colors.red),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _loadPrivacyPolicy() async {
    return await rootBundle.loadString('assets/policy/privacy-policy.txt');
  }
}
