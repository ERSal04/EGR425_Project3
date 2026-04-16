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
    print("\n[BLE] 🔍 Starting BLE scan...");
    gameState.showPersistentError("Scanning for M5Core2...");

    // Request Bluetooth permissions on Android
    if (Platform.isAndroid) {
      try {
        final scanStatus = await Permission.bluetoothScan.request();
        final connectStatus = await Permission.bluetoothConnect.request();
        await Permission.location.request();

        if (scanStatus.isDenied || connectStatus.isDenied) {
          gameState.showPersistentError(
            "Bluetooth permissions required. Please grant them in app settings.",
          );
          print("❌ [BLE] Bluetooth permissions denied.");
          return;
        }

        if (scanStatus.isPermanentlyDenied ||
            connectStatus.isPermanentlyDenied) {
          gameState.showPersistentError(
            "Bluetooth permissions permanently denied. Please enable in App Settings.",
          );
          print("⚠️  [BLE] Bluetooth permissions permanently denied.");
          openAppSettings();
          return;
        }
      } catch (e) {
        print("❌ [BLE] Permission request error: $e");
      }
    }

    // Make sure Bluetooth is on
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      gameState.showPersistentError("Bluetooth is off. Please enable it.");
      print("⚠️  [BLE] Bluetooth adapter is off.");
      return;
    }

    // Cancel any existing scan
    await FlutterBluePlus.stopScan();

    try {
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          print("[BLE] 📡 Found device: ${result.device.platformName}");
          // Look for our server by name
          if (result.device.platformName == serverName) {
            print("✅ [BLE] Found target device: $serverName!");
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
      print("[BLE] ⏱️  Scanning for 10 seconds...");
    } catch (e) {
      print("❌ [BLE] Scan error: $e");
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
    print("\n[BLE] 🔗 Attempting to connect to ${device.platformName}...");
    _device = device;
    gameState.showPersistentError("Connecting to ${device.platformName}...");

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      print("✅ [BLE] Connected to device! Discovering services...");

      // Listen for disconnection
      _connectionSubscription = device.connectionState.listen((state) {
        print("[BLE] Connection state changed: $state");
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });

      await _discoverServices();
    } catch (e) {
      print("❌ [BLE] Connection failed: $e");
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
    print("[BLE] 🔎 Discovered ${services.length} services");

    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
        print("✅ [BLE] Found target service!");
        for (BluetoothCharacteristic char in service.characteristics) {
          String uuid = char.uuid.toString().toLowerCase();

          if (uuid == defenderCharUuid.toLowerCase()) {
            _defenderChar = char;
            print("   ✓ Found DEFENDER characteristic (NOTIFY)");
            await _subscribeToDefenderNotifications();
          }

          if (uuid == hackerCharUuid.toLowerCase()) {
            _hackerChar = char;
            print("   ✓ Found HACKER characteristic (WRITE)");
          }
        }

        // Both characteristics found
        if (_defenderChar != null && _hackerChar != null) {
          _isConnected = true;
          gameState.clearError();
          gameState.setM5Connected(true, deviceName: _device!.platformName);
          print("\n✅ [BLE] Connected and ready! 🎮\n");
        } else {
          print("❌ [BLE] Characteristics not found on server.");
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
      print("\n═══════════════════════════════════════");
      print("[BLE] ⬇️ RECEIVED (${value.length} bytes): $payload");
      print("═══════════════════════════════════════\n");
      _parseDefenderPayload(payload);
    });

    print("[BLE] ✓ Subscribed to defender notifications.");
  }

  ///////////////////////////////////////////////////////////////
  // Parse defender payload: "T9,13|L-1|P0|SPLAY"
  // T = trace positions
  // L = locked node (-1 if none)
  // P = defender position (if available)
  // S = game status (SPLAY, SWIN, HWIN)
  // M = map selection (M0=MAP1, M1=MAP2)
  ///////////////////////////////////////////////////////////////
  void _parseDefenderPayload(String payload) {
    try {
      List<String> parts = payload.split('|');
      if (parts.length < 3) {
        print(
          "❌ [BLE] Invalid payload format (expected 3+ parts, got ${parts.length}): $payload",
        );
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

      // Extract defender position if available
      int? defenderNode;
      for (final part in parts) {
        if (part.startsWith('DEF:')) {
          try {
            defenderNode = int.parse(part.substring(4));
          } catch (e) {
            print("❌ [BLE] Parse defender node error: $e");
          }
        }
      }

      // ========== PARSE MAP SELECTION FROM M FIELD ==========
      // Format: M0 (MAP 1) or M1 (MAP 2)
      int mapIdToSet = 1; // Default to MAP 1
      for (final part in parts) {
        if (part.startsWith('M')) {
          try {
            int mapId = int.parse(part.substring(1)); // Extract 0 or 1
            gameState.setActiveMapFromBLE(mapId); // Convert 0→1, 1→2
            mapIdToSet = mapId;
          } catch (e) {
            print("❌ [BLE] Parse map ID error: $e");
          }
        }
      }

      // Update game state on main thread
      print(
        "[BLE] 📊 Parsed: Traces=$traces, Locked=$lockedNodes, Status=$statusPart, DefenderNode=$defenderNode, Map=${mapIdToSet + 1}",
      );

      gameState.updateMapFromDefender(
        traces: traces,
        locked: lockedNodes,
        defenderNode: defenderNode,
      );

      // Handle game over
      if (statusPart == "SWIN") {
        print("[BLE] 🛡️  DEFENDER WINS!");
        gameState.setGameOver("defender");
      } else if (statusPart == "HWIN") {
        print("[BLE] 🎯 HACKER WINS!");
        gameState.setGameOver("hacker");
      } else {
        // SPLAY — it's now the hacker's turn
        print("[BLE] ▶️  Hacker's turn");
        gameState.setCurrentTurn(CurrentTurn.hackerTurn);
      }
    } catch (e) {
      print("❌ [BLE] Parse error: $e");
      print("   Raw payload: $payload");
    }
  }

  ///////////////////////////////////////////////////////////////
  // Send hacker move to M5: "N15|TOOL:none" or "N6|TOOL:crack:9"
  // Format: N{currentNode}|TOOL:{toolName} or N{currentNode}|TOOL:{toolName}:{targetNode}
  // Call this after the hacker taps a node or uses a tool
  ///////////////////////////////////////////////////////////////
  Future<void> sendHackerMove(
    int nodeId, {
    String tool = "none",
    int? targetNode,
  }) async {
    // ========== VALIDATION ==========
    final maxNodeId = gameState.getMaxNodeId();
    if (nodeId < 0 || nodeId > maxNodeId) {
      print(
        "❌ [BLE] Invalid nodeId: $nodeId (must be 0-$maxNodeId). Not sending!",
      );
      gameState.showTransientError("Error: Invalid node ID ($nodeId)");
      return;
    }

    if (_hackerChar == null || !_isConnected) {
      print("❌ [BLE] Cannot send — not connected.");
      gameState.showTransientError("Not connected to M5");
      return;
    }

    // ========== BUILD PAYLOAD ==========
    String payload;
    if (targetNode != null && targetNode >= 0 && targetNode <= maxNodeId) {
      // Tools with targets: crack, tunnel, spoof
      payload = "N$nodeId|TOOL:$tool:$targetNode";
    } else {
      // Regular moves
      payload = "N$nodeId|TOOL:$tool";
    }

    List<int> bytes = utf8.encode(payload);

    try {
      print("\n═══════════════════════════════════════");
      print("[BLE] ⬆️  SENDING (${bytes.length} bytes): $payload");
      if (targetNode != null) {
        print(
          "       → Current Node: $nodeId, Tool: $tool, Target: $targetNode",
        );
      } else {
        print("       → Current Node: $nodeId, Tool: $tool");
      }
      print("═══════════════════════════════════════\n");

      await _hackerChar!.write(bytes, withoutResponse: false);
      print("✓ [BLE] Message sent successfully.\n");

      // Record what was sent for debug display
      String toolDetail = tool != "none"
          ? (targetNode != null ? "$tool:$targetNode" : tool)
          : "move";
      gameState.recordSentData("N$nodeId | $toolDetail");

      // Switch to defender's turn while waiting for response
      gameState.setCurrentTurn(CurrentTurn.defenderTurn);
    } catch (e) {
      print("❌ [BLE] Write error: $e\n");
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
    print(
      "\n⚠️  [BLE] Disconnected from device. Restarting scan in 2 seconds...\n",
    );
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
