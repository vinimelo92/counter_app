import 'dart:async';
import 'dart:convert' show utf8;
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Device identification (ESP32)
  final String SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  final String CHARACTERISTIC_UUID_TX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  final String CHARACTERISTIC_UUID_RX = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
  final String TARGET_DEVICE_NAME = "ESP32-BLE";

  FlutterBlue flutterBlue = FlutterBlue.instance;
  StreamSubscription<ScanResult> scanSubScription;

  // Variables for bluetooth
  BluetoothDevice targetDevice;
  BluetoothCharacteristic targetCharacteristicTX;
  BluetoothCharacteristic targetCharacteristicRX;

  // Variable for display info
  String connectionText = "Device Disconnected";
  String sCounterValue = "--";

  bool bIsConnected = false;
  bool bEnableRealTimeCounter = false;
  int iStatePauseOrPlay = 0;

  @override
  void initState() {
    super.initState();
  }

  startScan() {
    setState(() {
      connectionText = "Start Scanning";
    });

    scanSubScription = flutterBlue
        .scan(
      allowDuplicates: false,
      scanMode: ScanMode.lowLatency,
      timeout: const Duration(seconds: 12),
    )
        .listen((scanResult) {
      if (scanResult.device.name == TARGET_DEVICE_NAME) {
        stopScan();
        setState(() {
          connectionText = "Found Target Device";
        });

        targetDevice = scanResult.device;
        connectToDevice();
      }
    }, onDone: () => stopScan());
  }

  stopScan() {
    scanSubScription?.cancel();
    scanSubScription = null;
  }

  connectToDevice() async {
    if (targetDevice == null) return;

    setState(() {
      connectionText = "Device Connecting";
    });

    await targetDevice.connect();
    setState(() {
      connectionText = "Device Connected";
    });
    discoverServices();
  }

  disconnectFromDevice() {
    if (targetDevice == null) return;

    targetDevice.disconnect();
    targetDevice = null;
    bIsConnected = false;
    bEnableRealTimeCounter = false;
    setState(() {
      connectionText = "Device Disconnected";
    });
  }

  discoverServices() async {
    if (targetDevice == null) return;

    List<BluetoothService> services = await targetDevice.discoverServices();
    services.forEach((service) {
      // do something with service
      if (service.uuid.toString() == SERVICE_UUID) {
        service.characteristics.forEach((characteristic) {
          print(characteristic.uuid.toString());
          if (characteristic.uuid.toString() == CHARACTERISTIC_UUID_TX) {
            targetCharacteristicTX = characteristic;
            bIsConnected = true;
            setState(() {
              connectionText = "Connected to ${targetDevice.name}";
            });
          }
          if (characteristic.uuid.toString() == CHARACTERISTIC_UUID_RX) {
            targetCharacteristicRX = characteristic;
            targetCharacteristicRX.setNotifyValue(true);
            bIsConnected = true;
          }
        });
      }
    });

    services.clear();
  }

  sendData(String data) {
    if (targetCharacteristicTX == null) return;

    List<int> bytes = utf8.encode(data);
    targetCharacteristicTX.write(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text('Counter ESP/Bluetooth', textAlign: TextAlign.center),
          backgroundColor: Colors.blue,
        ),
        body: new ListView(
          padding: EdgeInsets.all(8.0),
          children: <Widget>[
            Card(
                elevation: 12.0,
                color: Colors.grey[300],
                child: ListTile(
                    title: Text(
                  'Bluetooth Connection',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                ))),
            Card(
              child: ListTile(
                leading: Icon(
                  (connectionText) == "Device Connected" || (bIsConnected)
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color:
                      (connectionText) == "Device Connected" || (bIsConnected)
                          ? Colors.blue
                          : Colors.grey,
                  size: 48.0,
                ),
                title: Text('Bluetooth Status:',
                    style:
                        TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold)),
                subtitle: Text('$connectionText'),
                onLongPress: () {
                  if (bIsConnected) {
                    disconnectFromDevice();
                    flutterBlue.stopScan();
                  } else {
                    startScan();
                  }
                },
              ),
            ),
            Card(
              elevation: 12.0,
              color: Colors.grey[300],
              child: ListTile(
                title: Text(
                  'Control commands',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Card(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  ListTile(
                    leading: IconButton(
                      icon: Icon(Icons.redo,
                          color: (bIsConnected) ? Colors.blue : Colors.grey),
                      tooltip: 'Upcounting',
                      iconSize: 48.0,
                      onPressed: () {
                        setState(() {
                          sendData("PROGRESSIVE");
                        });
                      },
                    ),
                    title: Text("Progressive counter"),
                  ),
                  ListTile(
                    leading: IconButton(
                      icon: Icon(Icons.undo,
                          color: (bIsConnected) ? Colors.blue : Colors.grey),
                      tooltip: 'Downcounting',
                      iconSize: 48.0,
                      onPressed: () {
                        setState(() {
                          sendData("REGRESSIVE");
                        });
                      },
                    ),
                    title: Text("Regressive counter"),
                  ),
                  ListTile(
                    leading: IconButton(
                      icon: iStatePauseOrPlay == 0
                          ? Icon(Icons.pause_circle_outline,
                              color: (bIsConnected) ? Colors.blue : Colors.grey)
                          : Icon(Icons.play_circle_outline,
                              color:
                                  (bIsConnected) ? Colors.blue : Colors.grey),
                      tooltip: iStatePauseOrPlay == 0 ? 'Pause' : 'Play',
                      iconSize: 48.0,
                      onPressed: () {
                        setState(() {
                          if (iStatePauseOrPlay == 0) {
                            iStatePauseOrPlay++;
                            sendData("PAUSE");
                          } else {
                            iStatePauseOrPlay--;
                            sendData("PLAY");
                          }
                        });
                      },
                    ),
                    title: Text(iStatePauseOrPlay == 0 ? "Pause" : "Play"),
                  ),
                  ListTile(
                    leading: IconButton(
                      icon: Icon(Icons.settings_backup_restore,
                          color: (bIsConnected) ? Colors.blue : Colors.grey),
                      tooltip: 'Reset',
                      iconSize: 48.0,
                      onPressed: () {
                        setState(() {
                          sendData("RESET");
                        });
                      },
                    ),
                    title: Text("Reset"),
                  ),
                ],
              ),
            ),
            Card(
              elevation: 12.0,
              color: Colors.grey[300],
              child: ListTile(
                title: Text(
                  'Real-time information',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                ),
                dense: true,
              ),
            ),
            Card(
              child: ListTile(
                leading: (!bEnableRealTimeCounter)
                    ? Icon(
                        Icons.timer,
                        size: 48.0,
                        color: Colors.grey,
                      )
                    : Icon(
                        Icons.timer,
                        size: 48.0,
                        color: Colors.blue,
                      ),
                title: Text(
                  'Counter: $sCounterValue',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                ),
                trailing: (bIsConnected
                    ? ((bEnableRealTimeCounter)
                        ? Text('Press to disable')
                        : Text('Press to enable'))
                    : Text('')),
                onLongPress: () {
                  if (!bEnableRealTimeCounter) {
                    if (bIsConnected) {
                      bEnableRealTimeCounter = true;
                      targetCharacteristicRX.value.listen((event) {
                        if (bEnableRealTimeCounter) {
                          sCounterValue = utf8.decode(event);
                          setState(() {});
                        }
                      });
                      setState(() {});
                    }
                  } else {
                    bEnableRealTimeCounter = false;
                    setState(() {});
                  }
                },
              ),
            ),
          ],
        ));
  }
}

final _MyHomePageState homePageState = new _MyHomePageState();
