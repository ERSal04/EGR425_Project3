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
  int _spoofUsesRemaining = 1;
  int _tunnelUsesRemaining = 1;
  int _firewallBreakUsesRemaining = 1;

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
  int get firewallBreakUsesRemaining => _firewallBreakUsesRemaining;
  int get timeRemaining => _timeRemaining;
  bool get isM5Connected => _isM5Connected;
  String? get errorMessage => _errorMessage;
  String? get gameWinner => _gameWinner;
  String get connectedDeviceName => _connectedDeviceName;

  // Helper to truncate device name
  String get displayDeviceName {
    const maxLength = 20;
    if (_connectedDeviceName.length > maxLength) {
      return _connectedDeviceName.substring(0, maxLength - 3) + '...';
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
      notifyListeners();
    }
  }

  void useTunnel() {
    if (_tunnelUsesRemaining > 0) {
      _tunnelUsesRemaining--;
      notifyListeners();
    }
  }

  void useFirewallBreak() {
    if (_firewallBreakUsesRemaining > 0) {
      _firewallBreakUsesRemaining--;
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
    _spoofUsesRemaining = 1;
    _tunnelUsesRemaining = 1;
    _firewallBreakUsesRemaining = 1;
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
