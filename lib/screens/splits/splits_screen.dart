import 'package:flutter/material.dart';

class SplitsScreen extends StatelessWidget {
  const SplitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Splits'),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Splits Screen - Coming Soon'),
      ),
    );
  }
}
