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

  void updateMapFromDefender({
    required List<int> traces,
    required List<int> locked,
    required int timeLeft,
  }) {
    _tracePositions = traces;
    _lockedNodes = locked;
    _timeRemaining = timeLeft;
    notifyListeners();
  }

  void useSpoof() {
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

      notifyListeners();
    }
  }

  void useTunnel() {
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
      notifyListeners();
    }
  }

  void useCrack() {
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

  /// Move hacker to an adjacent node
  /// Returns true if successful, false otherwise
  bool moveToNode(int targetNodeId) {
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

    // Check if hacker reached CORE (node 23) - WIN CONDITION
    if (targetNodeId == 23) {
      // Award victory to hacker
      setGameOver("hacker");
    }

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
}
