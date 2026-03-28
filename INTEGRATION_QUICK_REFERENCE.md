# Quick Integration Reference

## For Your Partner Meeting

Print this and use it as a checklist during your integration session.

---

## What's Ready Today

✅ **Game Logic** - All complete and tested
- Hacker movement with locked node handling
- Tool system (Spoof, Tunnel, Crack)
- Win conditions (reach CORE or caught by trace)
- Node graph and pathfinding

✅ **Game State Management** - Production code
- `updateMapFromDefender()` - receives M5 state
- All game rules and state tracking
- Turn management and tool cooldowns

✅ **UI** - Ready (minus debug)
- Game map rendering with movement
- Tool buttons and selection
- Status panel with game info

---

## What's Debug

🗑️ **main.dart** (10 lines to change)
```
Line 45-67: _simulateM5Connection() and _initializeDebugGameState()
```

🗑️ **game_state.dart** (100+ lines to remove)
```
Lines 424-619: All debug functions section
```

🗑️ **game_screen.dart** (3 sections)
```
1. Top bar: DBG button (30 lines)
2. Status panel: Debug controls (40 lines)
```

---

## Critical Code Locations

### For BLE Listen (add where M5 sends state):
```dart
// In main.dart, when CHAR_DEFENDER receives notification:
_handleDefenderStateUpdate(jsonDecode(value) as Map<String, dynamic>);
```

### For BLE Send (add after moves):
```dart
// In game_state.dart, after moveToNode() calls notifyListeners():
final payload = jsonEncode({
  'nodeId': targetNodeId,
  'tool': null,
  'toolsLeft': [_spoofUsesRemaining, _tunnelUsesRemaining, _crackUsesRemaining]
});
await bleWrite(CHAR_HACKER_UUID, payload);
```

---

## UUIDs to Use

```dart
const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String CHAR_DEFENDER_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String CHAR_HACKER_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a9";
```

---

## Search Markers

Find all work locations with these:
- `// TODO:` - Implementation points
- `// ============ PRODUCTION:` - Production code sections
- `// 🗑️` - Debug code to delete
- `// ============ DEBUG:` - Debug code to delete

---

## Testing Order

1. **Connect** - M5 appears in scan results
2. **Auto-Start** - Game enters connection_screen
3. **Move** - Hacker moves, BLE sends position
4. **Updates** - M5 sends traces, phone renders them
5. **Tools** - Try spoof, tunnel, crack with BLE sends
6. **Win/Loss** - Test both victory conditions

---

## Common Integration Mistakes

❌ Forgetting to send hacker position after `moveToNode()`
❌ Not parsing M5 JSON response to Map<String, dynamic>
❌ Leaving debug button in production
❌ Not calling `updateMapFromDefender()` when M5 notifies
❌ Forgetting to listen for CHAR_DEFENDER notifications

---

## Files to Modify

1. `lib/main.dart` - BLE connection + state receiver
2. `lib/models/game_state.dart` - Remove debug, add BLE sends
3. `lib/screens/game_screen.dart` - Delete debug UI buttons
4. (Optional) `lib/screens/connection_screen.dart` - Use for BLE scanning reference only

---

## Stay Safe

- Add BLE send calls **one at a time**, test each
- Keep game state logic **unchanged** - it's correct
- Test with **STATUS button** still visible during debugging
- **Commit to git** before removing debug code
- **Back up** your BLE connection code once working

---

## After Integration

1. Remove this file and BLE_INTEGRATION_GUIDE.md
2. Delete all `// TODO:` comments related to debug
3. Do final commit: "Remove debug code and integrate BLE"
4. Test entire game flow end-to-end
5. Ship it! 🚀
