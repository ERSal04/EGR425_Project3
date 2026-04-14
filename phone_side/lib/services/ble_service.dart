import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/game_state.dart';

///////////////////////////////////////////////////////////////
// BLE Service — handles all Bluetooth communication
// M5Core2 is the server, phone is the client
///////////////////////////////////////////////////////////////

class BleService {
  // UUIDs must match M5Core2 exactly
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String defenderCharUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8"; // NOTIFY
  static const String hackerCharUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9"; // WRITE
  static const String serverName = "HACKER_DEFENDER_GAME";

  final GameState gameState;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _defenderChar; // We read/subscribe to this
  BluetoothCharacteristic? _hackerChar; // We write to this

  StreamSubscription? _scanSubscription;
  StreamSubscription? _notifySubscription;
  StreamSubscription? _connectionSubscription;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  BleService({required this.gameState});

  ///////////////////////////////////////////////////////////////
  // Start scanning for the M5Core2
  ///////////////////////////////////////////////////////////////
  Future<void> startScan() async {
    gameState.showPersistentError("Scanning for M5Core2...");

    // Request Bluetooth permissions on Android
    if (Platform.isAndroid) {
      try {
        final scanStatus = await Permission.bluetoothScan.request();
        final connectStatus = await Permission.bluetoothConnect.request();
        final locationStatus = await Permission.location.request();

        if (scanStatus.isDenied || connectStatus.isDenied) {
          gameState.showPersistentError(
            "Bluetooth permissions required. Please grant them in app settings.",
          );
          return;
        }

        if (scanStatus.isPermanentlyDenied ||
            connectStatus.isPermanentlyDenied) {
          gameState.showPersistentError(
            "Bluetooth permissions permanently denied. Please enable in App Settings.",
          );
          openAppSettings();
          return;
        }
      } catch (e) {
        print("[BLE] Permission request error: $e");
      }
    }

    // Make sure Bluetooth is on
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      gameState.showPersistentError("Bluetooth is off. Please enable it.");
      return;
    }

    // Cancel any existing scan
    await FlutterBluePlus.stopScan();

    try {
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          // Look for our server by name
          if (result.device.platformName == serverName) {
            FlutterBluePlus.stopScan();
            _connectToDevice(result.device);
            break;
          }
        }
      });

      // Scan for 10 seconds then retry
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [Guid(serviceUuid)],
      );
    } catch (e) {
      print("[BLE] Scan error: $e");
      gameState.showPersistentError("Scan failed: $e");
      // Retry after delay
      await Future.delayed(const Duration(seconds: 3));
      startScan();
    }
  }

  ///////////////////////////////////////////////////////////////
  // Connect to the M5Core2 once found
  ///////////////////////////////////////////////////////////////
  Future<void> _connectToDevice(BluetoothDevice device) async {
    _device = device;
    gameState.showPersistentError("Connecting to ${device.platformName}...");

    try {
      await device.connect(timeout: const Duration(seconds: 10));

      // Listen for disconnection
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });

      await _discoverServices();
    } catch (e) {
      gameState.showPersistentError("Connection failed: $e");
      startScan(); // Retry scan
    }
  }

  ///////////////////////////////////////////////////////////////
  // Discover services and characteristics
  ///////////////////////////////////////////////////////////////
  Future<void> _discoverServices() async {
    if (_device == null) return;

    List<BluetoothService> services = await _device!.discoverServices();

    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
        for (BluetoothCharacteristic char in service.characteristics) {
          String uuid = char.uuid.toString().toLowerCase();

          if (uuid == defenderCharUuid.toLowerCase()) {
            _defenderChar = char;
            await _subscribeToDefenderNotifications();
          }

          if (uuid == hackerCharUuid.toLowerCase()) {
            _hackerChar = char;
          }
        }

        // Both characteristics found
        if (_defenderChar != null && _hackerChar != null) {
          _isConnected = true;
          gameState.clearError();
          gameState.setM5Connected(true, deviceName: _device!.platformName);
          print("[BLE] Connected and ready.");
        } else {
          gameState.showPersistentError("Characteristics not found on server.");
        }

        break;
      }
    }
  }

  ///////////////////////////////////////////////////////////////
  // Subscribe to defender NOTIFY characteristic
  // This fires every time M5 sends updated game state
  ///////////////////////////////////////////////////////////////
  Future<void> _subscribeToDefenderNotifications() async {
    if (_defenderChar == null) return;

    await _defenderChar!.setNotifyValue(true);

    _notifySubscription = _defenderChar!.onValueReceived.listen((value) {
      String payload = utf8.decode(value);
      print("[BLE] Received: $payload");
      _parseDefenderPayload(payload);
    });

    print("[BLE] Subscribed to defender notifications.");
  }

  ///////////////////////////////////////////////////////////////
  // Parse defender payload: "T9,13|L-1|SPLAY"
  // T = trace positions
  // L = locked node (-1 if none)
  // S = game status (SPLAY, SWIN, HWIN)
  ///////////////////////////////////////////////////////////////
  void _parseDefenderPayload(String payload) {
    try {
      List<String> parts = payload.split('|');
      if (parts.length < 3) {
        print("[BLE] Invalid payload format: $payload");
        return;
      }

      // Parse traces: "T9,13" → [9, 13]
      String tracePart = parts[0]; // "T9,13"
      List<int> traces = tracePart
          .substring(1) // Remove 'T'
          .split(',')
          .map((s) => int.tryParse(s.trim()) ?? -1)
          .where((n) => n != -1)
          .toList();

      // Parse locked node: "L7" → 7, "L-1" → no locked node
      String lockPart = parts[1]; // "L7" or "L-1"
      int lockedNodeId = int.tryParse(lockPart.substring(1)) ?? -1;
      List<int> lockedNodes = lockedNodeId >= 0 ? [lockedNodeId] : [];

      // Parse game status: "SPLAY", "SWIN", "HWIN"
      String statusPart = parts[2].trim();

      // Update game state on main thread
      gameState.updateMapFromDefender(
        traces: traces,
        locked: lockedNodes,
        timeLeft: gameState.timeRemaining, // Keep existing timer for now
      );

      // Handle game over
      if (statusPart == "SWIN") {
        gameState.setGameOver("defender");
      } else if (statusPart == "HWIN") {
        gameState.setGameOver("hacker");
      } else {
        // SPLAY — it's now the hacker's turn
        gameState.setCurrentTurn(CurrentTurn.hackerTurn);
      }
    } catch (e) {
      print("[BLE] Parse error: $e for payload: $payload");
    }
  }

  ///////////////////////////////////////////////////////////////
  // Send hacker move to M5: "N15|TOOL:none"
  // Call this after the hacker taps a node
  ///////////////////////////////////////////////////////////////
  Future<void> sendHackerMove(int nodeId, {String tool = "none"}) async {
    if (_hackerChar == null || !_isConnected) {
      print("[BLE] Cannot send — not connected.");
      return;
    }

    String payload = "N$nodeId|TOOL:$tool";
    List<int> bytes = utf8.encode(payload);

    try {
      await _hackerChar!.write(bytes, withoutResponse: false);
      print("[BLE] Sent: $payload");
      // Switch to defender's turn while waiting for response
      gameState.setCurrentTurn(CurrentTurn.defenderTurn);
    } catch (e) {
      print("[BLE] Write error: $e");
      gameState.showTransientError("Failed to send move.");
    }
  }

  ///////////////////////////////////////////////////////////////
  // Handle disconnection
  ///////////////////////////////////////////////////////////////
  void _handleDisconnect() {
    _isConnected = false;
    _defenderChar = null;
    _hackerChar = null;
    gameState.setM5Connected(false);
    gameState.showPersistentError("Disconnected. Rescanning...");
    print("[BLE] Disconnected. Restarting scan.");
    Future.delayed(const Duration(seconds: 2), () => startScan());
  }

  ///////////////////////////////////////////////////////////////
  // Clean up subscriptions
  ///////////////////////////////////////////////////////////////
  void dispose() {
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
    _device?.disconnect();
  }
}
