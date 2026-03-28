import 'package:flutter/material.dart';

// Enum for game phases
enum GamePhase {
  connecting, // Waiting for BLE connection
  selectingEntry, // Hacker picking entry node
  playing, // Active gameplay
  gameOver, // Game has ended
}

// Enum for whose turn it is
enum CurrentTurn { hackerTurn, defenderTurn }

// Enum for tool selection mode
enum ToolSelectionMode { none, tunnel, crack }

/// GameState manages all hacker-side game data
/// This is a ChangeNotifier so UI widgets can listen for updates
class GameState extends ChangeNotifier {
  // ========== Game Flow ==========
  GamePhase _gamePhase = GamePhase.connecting;
  CurrentTurn _currentTurn = CurrentTurn.defenderTurn;

  // ========== Hacker Position & Map ==========
  int _hackerCurrentNode = -1; // -1 = not placed yet
  List<int> _availableNodes = []; // Nodes hacker can move to
  List<int> _tracePositions = []; // Where defender's traces are
  List<int> _lockedNodes = []; // Locked nodes (grey out)

  // ========== Hacker Tools ==========
  int _spoofUsesRemaining = 3; // Spoof has 3 uses
  int _tunnelUsesRemaining = 1;
  int _crackUsesRemaining = 1;

  // ========== Tool Effects ==========
  bool _spoofActive = false; // Traces misdirected
  ToolSelectionMode _toolSelectionMode = ToolSelectionMode.none;
  List<int> _validToolTargets = []; // Valid nodes to select for current tool

  // ========== Game Status ==========
  int _timeRemaining = 300; // Seconds
  bool _isM5Connected = false;
  String? _errorMessage;
  String? _gameWinner; // "hacker", "defender", or null
  String _connectedDeviceName = "M5Core2";

  // ========== Getters ==========
  GamePhase get gamePhase => _gamePhase;
  CurrentTurn get currentTurn => _currentTurn;
  int get hackerCurrentNode => _hackerCurrentNode;
  List<int> get availableNodes => _availableNodes;
  List<int> get tracePositions => _tracePositions;
  List<int> get lockedNodes => _lockedNodes;
  int get spoofUsesRemaining => _spoofUsesRemaining;
  int get tunnelUsesRemaining => _tunnelUsesRemaining;
  int get crackUsesRemaining => _crackUsesRemaining;
  bool get spoofActive => _spoofActive;
  ToolSelectionMode get toolSelectionMode => _toolSelectionMode;
  List<int> get validToolTargets => _validToolTargets;
  int get timeRemaining => _timeRemaining;
  bool get isM5Connected => _isM5Connected;
  String? get errorMessage => _errorMessage;
  String? get gameWinner => _gameWinner;
  String get connectedDeviceName => _connectedDeviceName;

  // Helper to truncate device name
  String get displayDeviceName {
    const maxLength = 20;
    if (_connectedDeviceName.length > maxLength) {
      return '${_connectedDeviceName.substring(0, maxLength - 3)}...';
    }
    return _connectedDeviceName;
  }

  // Format time for display (mm:ss)
  String get formattedTime {
    int minutes = _timeRemaining ~/ 60;
    int seconds = _timeRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ========== Setters / Update Methods ==========

  void setGamePhase(GamePhase phase) {
    _gamePhase = phase;
    notifyListeners();
  }

  void setCurrentTurn(CurrentTurn turn) {
    _currentTurn = turn;
    notifyListeners();
  }

  void setHackerPosition(int nodeId) {
    _hackerCurrentNode = nodeId;
    notifyListeners();
  }

  void setAvailableNodes(List<int> nodes) {
    _availableNodes = nodes;
    notifyListeners();
  }

  /// ============ PRODUCTION: Called when M5 sends updated game state ============
  /// This is called from BLE listener when CHAR_DEFENDER_UUID receives:
  /// {"traces": [9, 13, 15], "locked": [7], "ping": false, "timeLeft": 42}
  ///
  /// Do NOT modify - this is production code
  void updateMapFromDefender({
    required List<int> traces,
    required List<int> locked,
    required int timeLeft,
  }) {
    _tracePositions = traces;
    _lockedNodes = locked;
    _timeRemaining = timeLeft;
    notifyListeners();

    // Check loss condition: trace on hacker node
    if (traces.contains(_hackerCurrentNode)) {
      setGameOver("defender");
    }
  }

  void useSpoof() {
    // ============ TURN CHECK ============
    if (_currentTurn != CurrentTurn.hackerTurn) {
      showTransientError(
        'Waiting for defender turn...',
        duration: const Duration(seconds: 2),
      );
      return;
    }
    if (_spoofUsesRemaining > 0) {
      _spoofUsesRemaining--;
      _spoofActive = true;
      showTransientError(
        'SPOOF activated - next ping shows false location',
        duration: const Duration(seconds: 2),
      );

      // Spoof effect lasts until next turn (1 turn cooldown)
      Future.delayed(const Duration(seconds: 1), () {
        _spoofActive = false;
        notifyListeners();
      });

      // ============ PRODUCTION: Send tool usage to M5 ============
      // TODO: After this line, send BLE update:
      //   await bleWrite(CHAR_HACKER_UUID, jsonEncode({
      //     'nodeId': _hackerCurrentNode,
      //     'tool': 'spoof',
      //     'toolsLeft': [_spoofUsesRemaining, _tunnelUsesRemaining, _crackUsesRemaining]
      //   }));

      notifyListeners();
    }
  }

  void useTunnel() {
    // ============ TURN CHECK ============
    if (_currentTurn != CurrentTurn.hackerTurn) {
      showTransientError(
        'Waiting for defender turn...',
        duration: const Duration(seconds: 2),
      );
      return;
    }
    if (_tunnelUsesRemaining > 0) {
      _tunnelUsesRemaining--;
      _toolSelectionMode = ToolSelectionMode.tunnel;
      // Entry nodes are 0, 1, 2, 3
      _validToolTargets = [0, 1, 2, 3];
      showTransientError(
        'TUNNEL active - tap a starting node',
        duration: const Duration(seconds: 2),
      );
      notifyListeners();
    }
  }

  void selectTunnelTarget(int entryNodeId) {
    if (_toolSelectionMode == ToolSelectionMode.tunnel &&
        _validToolTargets.contains(entryNodeId)) {
      _hackerCurrentNode = entryNodeId;
      _toolSelectionMode = ToolSelectionMode.none;
      _validToolTargets = [];
      showTransientError(
        'Tunneled to ${entryNodeId == 0
            ? 'ENTRY_A'
            : entryNodeId == 1
            ? 'ENTRY_B'
            : entryNodeId == 2
            ? 'ENTRY_C'
            : 'ENTRY_D'}',
        duration: const Duration(seconds: 2),
      );

      // ============ PRODUCTION: Send tunnel move to M5 ============
      // TODO: Send BLE update with new position:
      //   await bleWrite(CHAR_HACKER_UUID, jsonEncode({
      //     'nodeId': entryNodeId,
      //     'tool': 'tunnel',
      //     'toolsLeft': [_spoofUsesRemaining, _tunnelUsesRemaining, _crackUsesRemaining]
      //   }));

      notifyListeners();
    }
  }

  void useCrack() {
    // ============ TURN CHECK ============
    if (_currentTurn != CurrentTurn.hackerTurn) {
      showTransientError(
        'Waiting for defender turn...',
        duration: const Duration(seconds: 2),
      );
      return;
    }
    if (_crackUsesRemaining > 0) {
      _crackUsesRemaining--;
      _toolSelectionMode = ToolSelectionMode.crack;
      // Get locked neighbors
      final lockedNeighbors =
          GameState.nodeConnections[_hackerCurrentNode]
              ?.where((n) => _lockedNodes.contains(n))
              .toList() ??
          [];
      _validToolTargets = lockedNeighbors;
      if (lockedNeighbors.isEmpty) {
        showTransientError(
          'No adjacent locked nodes to crack!',
          duration: const Duration(seconds: 2),
        );
        _toolSelectionMode = ToolSelectionMode.none;
        _crackUsesRemaining++; // Refund use
      } else {
        showTransientError(
          'CRACK active - tap a locked node to unlock',
          duration: const Duration(seconds: 2),
        );
      }
      notifyListeners();
    }
  }

  void selectCrackTarget(int lockedNodeId) {
    if (_toolSelectionMode == ToolSelectionMode.crack &&
        _validToolTargets.contains(lockedNodeId)) {
      _lockedNodes.remove(lockedNodeId);
      _toolSelectionMode = ToolSelectionMode.none;
      _validToolTargets = [];
      showTransientError(
        'Node unlocked!',
        duration: const Duration(seconds: 2),
      );

      // ============ PRODUCTION: Send crack attempt to M5 ============
      // TODO: Send BLE update to notify M5 of unlock attempt:
      //   await bleWrite(CHAR_HACKER_UUID, jsonEncode({
      //     'nodeId': _hackerCurrentNode,
      //     'tool': 'crack',
      //     'crackedNode': lockedNodeId,
      //     'toolsLeft': [_spoofUsesRemaining, _tunnelUsesRemaining, _crackUsesRemaining]
      //   }));

      notifyListeners();
    }
  }

  void setM5Connected(bool connected, {String deviceName = "M5Core2"}) {
    _isM5Connected = connected;
    if (connected) {
      _connectedDeviceName = deviceName;
    }
    notifyListeners();
  }

  /// Show a transient error (auto-dismisses after duration)
  void showTransientError(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _errorMessage = message;
    notifyListeners();
    Future.delayed(duration, () {
      if (_errorMessage == message) {
        _errorMessage = null;
        notifyListeners();
      }
    });
  }

  /// Show a persistent error (stays until cleared)
  void showPersistentError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setGameOver(String winner) {
    _gameWinner = winner; // "hacker" or "defender"
    _gamePhase = GamePhase.gameOver;
    notifyListeners();
  }

  void resetGame() {
    _gamePhase = GamePhase.connecting;
    _currentTurn = CurrentTurn.defenderTurn;
    _hackerCurrentNode = -1;
    _availableNodes = [];
    _tracePositions = [];
    _lockedNodes = [];
    _spoofUsesRemaining = 3;
    _tunnelUsesRemaining = 1;
    _crackUsesRemaining = 1;
    _spoofActive = false;
    _toolSelectionMode = ToolSelectionMode.none;
    _validToolTargets = [];
    _timeRemaining = 300;
    _gameWinner = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Called when hacker selects an entry node
  void hackerSelectEntry(int entryNodeId) {
    _hackerCurrentNode = entryNodeId;
    _gamePhase = GamePhase.playing;
    _currentTurn = CurrentTurn.hackerTurn; // Always start on hacker's turn
    notifyListeners();
  }

  /// Define node adjacency map (which nodes connect to which)
  /// This is the network topology
  static const Map<int, List<int>> nodeConnections = {
    // Entry nodes (4 starting points)
    0: [4, 6],
    1: [5, 8],
    2: [6, 11],
    3: [8, 12],
    // First ring
    4: [0, 5, 7],
    5: [1, 4, 8],
    6: [0, 2, 9, 11],
    7: [4, 5, 9, 10],
    8: [1, 3, 5, 10, 12],
    // Second ring
    9: [6, 7, 13, 15],
    10: [7, 8, 14, 15],
    11: [2, 6, 13, 16],
    12: [3, 8, 14, 17],
    // Chokepoint layer
    13: [9, 11, 15, 18],
    14: [10, 12, 15, 19],
    15: [9, 10, 13, 14, 23], // JUNCTION - all paths funnel to here
    // Upper paths
    16: [11, 18, 20],
    17: [12, 19, 21],
    18: [13, 16, 19, 22],
    19: [14, 17, 18, 22],
    20: [16, 21, 22],
    21: [17, 20, 22],
    22: [18, 19, 20, 21],
    // CORE - ONLY REACHABLE VIA JUNCTION (node 15)
    23: [15],
  };

  /// Get neighbor nodes (accessible from hackerCurrentNode)
  List<int> getAccessibleNeighbors() {
    if (_hackerCurrentNode < 0) return [];
    List<int> neighbors = nodeConnections[_hackerCurrentNode] ?? [];
    // Filter out locked nodes
    List<int> accessible = neighbors
        .where((node) => !_lockedNodes.contains(node))
        .toList();
    return accessible;
  }

  /// ============ PRODUCTION: Move hacker to an adjacent node ============
  /// Call this when hacker taps a neighboring node on the game map
  ///
  /// TURN CHECK: Only allowed on hacker's turn
  ///
  /// AFTER calling this, you MUST send the move to M5 via BLE:
  ///   await bleWrite(CHAR_HACKER_UUID, jsonEncode({
  ///     'nodeId': targetNodeId,
  ///     'tool': lastToolUsed,  // 'spoof', 'tunnel', 'crack', or null
  ///     'toolsLeft': [_spoofUsesRemaining, _tunnelUsesRemaining, _crackUsesRemaining]
  ///   }));
  ///
  /// Returns true if successful, false otherwise
  bool moveToNode(int targetNodeId) {
    // ============ TURN CHECK ============
    if (_currentTurn != CurrentTurn.hackerTurn) {
      showTransientError(
        'Waiting for defender turn to end...',
        duration: const Duration(seconds: 2),
      );
      return false;
    }

    if (_hackerCurrentNode < 0) {
      showTransientError("Hacker not yet placed!");
      return false;
    }

    final neighbors = getAccessibleNeighbors();
    if (!neighbors.contains(targetNodeId)) {
      showTransientError("Can only move to adjacent nodes!");
      return false;
    }

    if (_lockedNodes.contains(targetNodeId)) {
      showTransientError("Node is locked! Use Crack to unlock.");
      return false;
    }

    _hackerCurrentNode = targetNodeId;
    if (_spoofActive) {
      showTransientError(
        'Move hidden by SPOOF (one turn)',
        duration: const Duration(milliseconds: 500),
      );
    }
    notifyListeners();

    // ============ CHECK WIN CONDITIONS IMMEDIATELY ============
    // Check for immediate catch (trace on this node)
    if (_tracePositions.contains(targetNodeId)) {
      setGameOver("defender");
      showPersistentError(
        'You entered a node with a trace! CONNECTION TERMINATED',
      );
      return true; // Move was registered before caught
    }

    // Check if hacker reached CORE (node 23) - WIN CONDITION
    if (targetNodeId == 23) {
      setGameOver("hacker");
      return true;
    }

    // TODO: After BLE integration, send move to M5 and switch to defender's turn
    // For now in debug, switch turns
    _currentTurn = CurrentTurn.defenderTurn;
    showTransientError(
      'Waiting for Defender turn...',
      duration: const Duration(seconds: 1),
    );

    return true;
  }

  /// Called when hacker attempts to move to a node
  /// Returns true if move is valid, false otherwise
  bool attemptMove(int targetNodeId) {
    if (!_availableNodes.contains(targetNodeId)) {
      showTransientError("Cannot move to that node!");
      return false;
    }
    if (_lockedNodes.contains(targetNodeId)) {
      showTransientError("Node is locked!");
      return false;
    }
    _hackerCurrentNode = targetNodeId;
    notifyListeners();
    return true;
  }

  // ========== DEBUG FUNCTIONS (TODO: Remove when BLE enabled) ==========
  // ═══════════════════════════════════════════════════════════════════════════
  // 🗑️  ENTIRE SECTION BELOW IS DEBUG-ONLY - DELETE ALL OF THIS FOR PRODUCTION
  // 🗑️  These functions simulate defender behavior for testing without M5Core2
  // 🗑️  They will NOT be needed once BLE is connected to real M5
  // ═══════════════════════════════════════════════════════════════════════════

  /// DEBUG: Set trace positions for testing defender behavior
  /// TODO: Remove when connected to real M5 defender
  void setDebugTraces(List<int> traceNodes) {
    _tracePositions = traceNodes;
    showTransientError(
      'DEBUG: Traces deployed at ${traceNodes.join(", ")}',
      duration: const Duration(seconds: 2),
    );
    notifyListeners();
  }

  /// DEBUG: Set locked nodes for testing crack tool
  /// TODO: Remove when connected to real M5 defender
  void setDebugLockedNodes(List<int> lockedNodes) {
    _lockedNodes = lockedNodes;
    showTransientError(
      'DEBUG: Nodes ${lockedNodes.join(", ")} are locked',
      duration: const Duration(seconds: 2),
    );
    notifyListeners();
  }

  /// DEBUG: Advance all traces one step closer to the hacker
  /// Simulates defender deploying new moves
  /// TODO: Remove when connected to real M5 defender
  void advanceDebugTraces() {
    if (_tracePositions.isEmpty) return;

    final newTraces = <int>[];
    for (final traceNode in _tracePositions) {
      final nextNode = _getNextNodeTowardTarget(traceNode, _hackerCurrentNode);
      newTraces.add(nextNode);

      // Check if this trace just caught the hacker
      if (nextNode == _hackerCurrentNode) {
        setGameOver("defender");
        showPersistentError('TRACE CAUGHT YOU AT NODE $_hackerCurrentNode!');
        return;
      }
    }

    _tracePositions = newTraces;
    notifyListeners();
  }

  /// DEBUG: Check if any trace is on the hacker's node
  /// TODO: Remove when connected to real M5 defender
  bool debugCheckIfCaught() {
    if (_tracePositions.contains(_hackerCurrentNode)) {
      setGameOver("defender");
      return true;
    }
    return false;
  }

  /// Helper: Get the next node on shortest path from source to target
  /// Used by defender traces to pursue the hacker
  /// TODO: Remove when connected to real M5 defender
  int _getNextNodeTowardTarget(int sourceNodeId, int targetNodeId) {
    if (sourceNodeId == targetNodeId) return sourceNodeId;

    // BFS to find shortest path
    final queue = <int>[sourceNodeId];
    final visited = {sourceNodeId};
    final parent = <int, int>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (current == targetNodeId) {
        // Reconstruct path backward from target to source
        var node = targetNodeId;
        while (parent[node] != sourceNodeId) {
          node = parent[node]!;
        }
        return node;
      }

      final neighbors = nodeConnections[current] ?? [];
      for (final neighbor in neighbors) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          parent[neighbor] = current;
          queue.add(neighbor);
        }
      }
    }

    // No path found (shouldn't happen on connected graph)
    return sourceNodeId;
  }

  /// DEBUG: Get all info for debugging overlay
  /// TODO: Remove when BLE is fully integrated
  Map<String, dynamic> getDebugInfo() {
    return {
      'hackerNode': _hackerCurrentNode,
      'tracePositions': _tracePositions,
      'lockedNodes': _lockedNodes,
      'connectedToM5': _isM5Connected,
      'gamePhase': _gamePhase.toString(),
      'spoofActive': _spoofActive,
      'toolMode': _toolSelectionMode.toString(),
      'timeRemaining': _timeRemaining,
    };
  }

  /// DEBUG: Create a perimeter lock pattern (useful for testing pathfinding)
  /// Locks nodes around the hacker to test navigation
  /// TODO: Remove when BLE enabled
  void debugSetPerimeterLock() {
    final neighbors = getAccessibleNeighbors();
    _lockedNodes = neighbors
        .take(2)
        .toList(); // Lock first 2 accessible neighbors
    showTransientError(
      'DEBUG: Perimeter lock set on nodes ${_lockedNodes.join(", ")}',
      duration: const Duration(seconds: 2),
    );
    notifyListeners();
  }

  /// DEBUG: Simulate multiple traces pursuing from entry points
  /// TODO: Remove when BLE enabled
  void debugSetAggressiveTraces() {
    // Deploy traces from multiple entry points toward hacker
    _tracePositions = [0, 1, 2, 3].take(2).toList(); // Start from corners
    showTransientError(
      'DEBUG: Aggressive traces deployed from entry points',
      duration: const Duration(seconds: 2),
    );
    notifyListeners();
  }

  /// DEBUG: Clear all traces and locks for a fresh test
  /// TODO: Remove when BLE enabled
  void debugClearAll() {
    _tracePositions = [];
    _lockedNodes = [];
    showTransientError(
      'DEBUG: All traces and locks cleared',
      duration: const Duration(seconds: 2),
    );
    notifyListeners();
  }

  /// DEBUG: Teleport hacker to a specific node (for testing specific scenarios)
  /// TODO: Remove when BLE enabled
  void debugTeleportTo(int nodeId) {
    if (nodeId < 0 || nodeId > 23) {
      showTransientError(
        'Invalid node ID: $nodeId',
        duration: const Duration(seconds: 2),
      );
      return;
    }
    _hackerCurrentNode = nodeId;
    showTransientError(
      'DEBUG: Teleported to node $nodeId',
      duration: const Duration(seconds: 1),
    );
    notifyListeners();
  }

  /// DEBUG: Get the shortest path between two nodes (for testing navigation)
  /// TODO: Remove when BLE enabled
  List<int> debugGetPathBetweenNodes(int fromNode, int toNode) {
    final queue = <List<int>>[
      [fromNode],
    ];
    final visited = {fromNode};

    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final current = path.last;

      if (current == toNode) {
        return path;
      }

      final neighbors = nodeConnections[current] ?? [];
      for (final neighbor in neighbors) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          queue.add([...path, neighbor]);
        }
      }
    }

    return []; // No path found
  }

  /// DEBUG: Toggle between hacker and defender turns
  /// TODO: Remove when BLE enabled
  void debugSwitchTurn() {
    _currentTurn = _currentTurn == CurrentTurn.hackerTurn
        ? CurrentTurn.defenderTurn
        : CurrentTurn.hackerTurn;
    showTransientError(
      'DEBUG: Switched to ${_currentTurn == CurrentTurn.hackerTurn ? 'HACKER' : 'DEFENDER'} turn',
      duration: const Duration(seconds: 1),
    );
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🗑️  END DEBUG SECTION - DELETE EVERYTHING ABOVE WHEN BLE IS READY
  // ═══════════════════════════════════════════════════════════════════════════
}
