import 'package:flutter/material.dart';

class AddSplitScreen extends StatelessWidget {
  const AddSplitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Bill'),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Add Split Screen - Coming Soon'),
      ),
    );
  }
}
