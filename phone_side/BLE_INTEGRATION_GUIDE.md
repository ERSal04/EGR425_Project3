# BLE Integration Checklist

## Overview
This document outlines exactly what needs to be done to integrate real BLE communication and remove all debug code.

---

## Phase 1: Remove Debug Initialization (main.dart)

### File: `lib/main.dart` - `_HomePageState.initState()`

**What to do:**
1. Keep `_simulateM5Connection()` but rename it to `_initBLEConnection()`
2. Replace the internal logic of `_simulateM5Connection()`:
   - [ ] Call `flutter_blue_plus` to scan for M5Core2 devices
   - [ ] Connect to the M5Core2 device
   - [ ] Subscribe to `CHAR_DEFENDER_UUID` (BLE characteristic) for state updates
   - [ ] Set up listener to call `_handleDefenderStateUpdate()` when data arrives

3. **DELETE** the entire `_initializeDebugGameState()` function call

### BLE Connection Blueprint
```dart
void _initBLEConnection() {
  // 1. Scan for devices
  FlutterBluePlus.startScan();
  
  // 2. Listen for scan results
  scanResults.listen((results) {
    for (ScanResult r in results) {
      if (r.device.name == "M5Core2") {
        r.device.connect();
        // Connect and subscribe to characteristics
      }
    }
  });
}
```

---

## Phase 2: Implement Real Game State Updates (game_state.dart)

### ✅ Already Production-Ready
The following methods are ready and need **NO changes**:
- `updateMapFromDefender()` - Called when M5 sends state updates
- `moveToNode()` - Hacker movement logic
- `useSpoof()`, `useTunnel()`, `useCrack()` - Tool usage

### 🗑️ DELETE Everything Between These Markers

**Location:** `lib/models/game_state.dart` - Bottom of file

```
// ═══════════════════════════════════════════════════════════════════════════
// 🗑️  ENTIRE SECTION BELOW IS DEBUG-ONLY - DELETE ALL OF THIS FOR PRODUCTION
```

All functions starting with `setDebugTraces()` through `debugGetPathBetweenNodes()` should be deleted.

### Functions to Delete:
- [ ] `setDebugTraces()`
- [ ] `setDebugLockedNodes()`
- [ ] `advanceDebugTraces()`
- [ ] `debugCheckIfCaught()`
- [ ] `_getNextNodeTowardTarget()`
- [ ] `getDebugInfo()`
- [ ] `debugSetPerimeterLock()`
- [ ] `debugSetAggressiveTraces()`
- [ ] `debugClearAll()`
- [ ] `debugTeleportTo()`
- [ ] `debugGetPathBetweenNodes()`

---

## Phase 3: Add BLE Write When Hacker Moves (game_state.dart)

### In `moveToNode()` method:
After the line `notifyListeners();`, add:

```dart
// ============ PRODUCTION: Send move to M5 ============
// TODO: Implement BLE write to CHAR_HACKER_UUID
final movePayload = jsonEncode({
  'nodeId': targetNodeId,
  'tool': null,  // Or 'spoof', 'tunnel', 'crack' if using a tool
  'toolsLeft': [_spoofUsesRemaining, _tunnelUsesRemaining, _crackUsesRemaining]
});
// await bleCharacteristicWrite(CHAR_HACKER_UUID, movePayload);
```

### In `useSpoof()` method:
After `notifyListeners();`, add BLE write:

```dart
final toolPayload = jsonEncode({
  'nodeId': _hackerCurrentNode,
  'tool': 'spoof',
  'toolsLeft': [_spoofUsesRemaining, _tunnelUsesRemaining, _crackUsesRemaining]
});
// await bleCharacteristicWrite(CHAR_HACKER_UUID, toolPayload);
```

### In `selectTunnelTarget()` method:
After `notifyListeners();`, add BLE write:

```dart
final tunnelPayload = jsonEncode({
  'nodeId': entryNodeId,
  'tool': 'tunnel',
  'toolsLeft': [_spoofUsesRemaining, _tunnelUsesRemaining, _crackUsesRemaining]
});
// await bleCharacteristicWrite(CHAR_HACKER_UUID, tunnelPayload);
```

### In `selectCrackTarget()` method:
After `notifyListeners();`, add BLE write:

```dart
final crackPayload = jsonEncode({
  'nodeId': _hackerCurrentNode,
  'tool': 'crack',
  'crackedNode': lockedNodeId,
  'toolsLeft': [_spoofUsesRemaining, _tunnelUsesRemaining, _crackUsesRemaining]
});
// await bleCharacteristicWrite(CHAR_HACKER_UUID, crackPayload);
```

---

## Phase 4: Remove Debug UI (game_screen.dart)

### 🗑️ Location 1: Top Bar Debug Button

**Find:** Look for the comment `// ============ DEBUG BUTTON - REMOVE THIS ENTIRE SECTION ============`

**Delete:**
- [ ] The entire `GestureDetector` widget for the "DBG" button (the purple button)
- [ ] Keep the "STATUS" button - that's still useful for testing

### 🗑️ Location 2: Status Panel Debug Controls

**Find:** Look for the comment `// ═══════════════════════════════════════════════════════════════════════════`
**Section:** Inside `_GameStatePanel` class

**Delete:**
- [ ] The "DEBUG TRACE CONTROLS" section
- [ ] "Advance Traces" button
- [ ] "Check Caught?" button
- [ ] The divider line above it

---

## Phase 5: Handle BLE State Receiver (main.dart)

### Implementation: `_handleDefenderStateUpdate()`

This function is already defined but needs to be connected to the BLE listener:

```dart
void _handleDefenderStateUpdate(Map<String, dynamic> defenderState) {
  final gameState = context.read<GameState>();
  
  // Parse incoming data from M5Core2
  final traces = List<int>.from(defenderState['traces'] ?? []);
  final locked = List<int>.from(defenderState['locked'] ?? []);
  final timeLeft = defenderState['timeLeft'] ?? 300;
  
  // Update game state - THIS METHOD CHECKS WIN CONDITION
  gameState.updateMapFromDefender(
    traces: traces,
    locked: locked,
    timeLeft: timeLeft,
  );
}
```

**Call this from your BLE listener** whenever `CHAR_DEFENDER_UUID` notifies new data.

---

## BLE Communication Reference

### UUIDs (from README.md)
```
SERVICE_UUID       = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
CHAR_DEFENDER_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8"  // NOTIFY
CHAR_HACKER_UUID   = "beb5483e-36e1-4688-b7f5-ea07361b26a9"  // WRITE
```

### Phone → M5 (Hacker Move)
Send to `CHAR_HACKER_UUID`:
```json
{ 
  "nodeId": 15, 
  "tool": "spoof",
  "toolsLeft": [2, 1, 1]
}
```

### M5 → Phone (Defender State)
Receive from `CHAR_DEFENDER_UUID`:
```json
{ 
  "traces": [9, 13, 15], 
  "locked": [7], 
  "ping": false, 
  "timeLeft": 42 
}
```

---

## Integration Points Summary

| Location | Change | Action |
|---|---|---|
| `main.dart` - `initState()` | Remove `_initializeDebugGameState()` call | DELETE |
| `main.dart` - `_simulateM5Connection()` | Rename & reimplement with real BLE | REPLACE |
| `game_state.dart` - Bottom | All debug functions | DELETE SECTION |
| `game_state.dart` - `moveToNode()` | Add BLE write | ADD |
| `game_state.dart` - `useSpoof()` | Add BLE write | ADD |
| `game_state.dart` - `selectTunnelTarget()` | Add BLE write | ADD |
| `game_state.dart` - `selectCrackTarget()` | Add BLE write | ADD |
| `game_screen.dart` - Top bar | Remove DBG button | DELETE |
| `game_screen.dart` - Status panel | Remove debug controls | DELETE |

---

## Testing Checklist

Once BLE is integrated:

- [ ] Device connects to M5Core2 on startup
- [ ] Game starts at connection screen
- [ ] Hacker can select entry node
- [ ] Hacker movement sends BLE messages to M5
- [ ] Traces update in real-time from M5
- [ ] Locked nodes display correctly from M5
- [ ] Spoof tool sends to M5 and affects defender
- [ ] Tunnel tool moves hacker and sends to M5
- [ ] Crack tool removes locks and send to M5
- [ ] Win: Hacker reaches CORE → "ACCESS GRANTED"
- [ ] Win: Trace catches hacker → "CONNECTION TERMINATED"
- [ ] Timer updates from M5

---

## Comments to Search For

Search your code for these markers to find all debug code:

```
TODO:
DEBUG:
🗑️
PRODUCTION:
============
```

All "TODO" comments point to exact places needing changes.

---

## Final Notes

- The game state management is **production-ready** - test it thoroughly
- Most UI is **production-ready** - just remove debug buttons
- The **core logic** is correct - only BLE plumbing needs to be added
- All game rules are implemented and working correctly
- Comments in code clearly mark what stays vs. what goes
