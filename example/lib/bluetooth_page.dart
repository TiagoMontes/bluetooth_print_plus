import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'function_page.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  BluetoothDevice? _device;
  late StreamSubscription<bool> _isScanningSubscription;
  late StreamSubscription<BlueState> _blueStateSubscription;
  late StreamSubscription<ConnectState> _connectStateSubscription;
  late StreamSubscription<Uint8List> _receivedDataSubscription;
  late StreamSubscription<List<BluetoothDevice>> _scanResultsSubscription;
  List<BluetoothDevice> _scanResults = [];

  @override
  void initState() {
    super.initState();
    initBluetoothPrintPlusListen();
  }

  @override
  void dispose() {
    super.dispose();
    _isScanningSubscription.cancel();
    _blueStateSubscription.cancel();
    _connectStateSubscription.cancel();
    _receivedDataSubscription.cancel();
    _scanResultsSubscription.cancel();
    _scanResults.clear();
  }

  Future<void> initBluetoothPrintPlusListen() async {
    /// listen scanResults
    _scanResultsSubscription = BluetoothPrintPlus.scanResults.listen((event) {
      if (mounted) {
        setState(() {
          _scanResults = event;
        });
      }
    });

    /// listen isScanning
    _isScanningSubscription = BluetoothPrintPlus.isScanning.listen((event) {
      print('********** isScanning: $event **********');
      if (mounted) {
        setState(() {});
      }
    });

    /// listen blue state
    _blueStateSubscription = BluetoothPrintPlus.blueState.listen((event) {
      print('********** blueState change: $event **********');
      if (mounted) {
        setState(() {});
      }
    });

    /// listen connect state
    _connectStateSubscription = BluetoothPrintPlus.connectState.listen((event) {
      print('********** connectState change: $event **********');
      switch (event) {
        case ConnectState.connected:
          setState(() {
            if (_device == null) return;
            Navigator.push(
                context,
                MaterialPageRoute(
                    // builder: (context) => FunctionPage(_device!)));
                    builder: (context) => FunctionPage(_device!)));
          });
          break;
        case ConnectState.disconnected:
          setState(() {
            _device = null;
          });
          break;
      }
    });

    /// listen received data
    _receivedDataSubscription = BluetoothPrintPlus.receivedData.listen((data) {
      print('********** received data: $data **********');

      /// do something...
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Connect to bluetooth'),
        ),
        body: SafeArea(
            child: BluetoothPrintPlus.isBlueOn
                ? ListView(
              children: _scanResults
                  .map((device) => Container(
                padding: EdgeInsets.only(
                    left: 10, right: 10, bottom: 5),
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(device.name),
                            Text(
                              device.address,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            Divider(),
                          ],
                        )),
                    SizedBox(
                      width: 10,
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        _device = device;
                        await BluetoothPrintPlus.connect(device);
                      },
                      child: const Text("connect"),
                    )
                  ],
                ),
              ))
                  .toList(),
            )
                : buildBlueOffWidget()),
        floatingActionButton:
        BluetoothPrintPlus.isBlueOn ? buildScanButton(context) : null);
  }

  Widget buildBlueOffWidget() {
    return Center(
        child: Text(
          "Bluetooth is turned off\nPlease turn on Bluetooth...",
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 16, color: Colors.red),
          textAlign: TextAlign.center,
        ));
  }

  Widget buildScanButton(BuildContext context) {
    if (BluetoothPrintPlus.isScanningNow) {
      return FloatingActionButton(
        onPressed: onStopPressed,
        backgroundColor: Colors.red,
        child: Icon(Icons.stop),
      );
    } else {
      return FloatingActionButton(
          onPressed: onScanPressed,
          backgroundColor: Colors.green,
          child: Text("SCAN"));
    }
  }

  Future onScanPressed() async {
    try {
      await BluetoothPrintPlus.startScan(timeout: Duration(seconds: 10));
    } catch (e) {
      print("onScanPressed error: $e");
    }
  }

  Future onStopPressed() async {
    try {
      BluetoothPrintPlus.stopScan();
    } catch (e) {
      print("onStopPressed error: $e");
    }
  }
}
