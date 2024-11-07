import 'package:flutter/material.dart';

class DocumentSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> documents;

  const DocumentSection({
    super.key,
    required this.title,
    required this.documents,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Helvetica',
            ),
          ),
        ),
        Card(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];
              return ListTile(
                leading: const Icon(Icons.description),
                title: Text(
                  document['name'],
                  style: const TextStyle(fontFamily: 'Helvetica'),
                ),
                subtitle: Text(
                  document['date'],
                  style: const TextStyle(fontFamily: 'Helvetica'),
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Handle document tap
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
