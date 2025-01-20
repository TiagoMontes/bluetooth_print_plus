import 'package:flutter/material.dart';
import 'bluetooth_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BluetoothPage()),
            );
          },
          child: const Text('Ir para Bluetooth'),
        ),
      ),
    );
  }
}
