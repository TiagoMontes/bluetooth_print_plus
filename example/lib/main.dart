import 'package:bluetooth_print_plus_example/bluetooth_page.dart';
import 'package:bluetooth_print_plus_example/settings_page.dart';
import 'package:flutter/material.dart';
import 'app_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplicação Bluetooth',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Página Inicial')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BluetoothPage()),
                );
              },
              child: const Text('Configurar Bluetooth'),
            ),
          ],
        ),
      ),
    );
  }
}
