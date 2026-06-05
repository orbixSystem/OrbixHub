import 'package:flutter/material.dart';

/// Placeholder for a product module screen (OS, inventory, customers). The real
/// module UIs are out of scope for this milestone; this exists so module-gated
/// navigation and route guards have a concrete target to demonstrate.
class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({super.key, required this.moduleKey});

  final String moduleKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Módulo: $moduleKey')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 48),
            const SizedBox(height: 12),
            Text(
              'Tela do módulo "$moduleKey" em breve.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
