#pragma once
#include <Arduino.h>

// ─── Enums ───────────────────────────────────────────────
enum NodeType   { NORMAL, ENTRY, JUNCTION, CORE };
enum Occupant   { NONE, HACKER, TRACE };
enum gameStatus { WAITING_TO_CONNECT, MAP_SELECT, HACKER_SELECT, GAME_IN_PROGRESS, GAME_OVER, LEADERBOARD };
enum playerTurn { HACKER_TURN, DEFENDER_TURN };
enum gameResult { NONE_RESULT, HACKER_WIN, DEFENDER_WIN };
enum defenderUIState { MAP_VIEW, NODE_SELECT, TOOL_SELECT };
enum DefenderTool    { TOOL_NODELOCK, TOOL_SPEEDBOOST, TOOL_PINGSCAN };

// ─── Node Struct ─────────────────────────────────────────
struct Node {
    int id;
    float worldX, worldY;
    NodeType type;
    Occupant occupant = NONE;
    int traceCount    = 0;
    bool isLocked     = false;
    int connections[6];
    int connectionCount = 0;
};

// ─── Map Data ────────────────────────────────────────────
extern Node nodes[25];
Node makeNode(int id, float x, float y, NodeType type, int conns[], int connCount);

// ─── Game State ──────────────────────────────────────────
extern int hackerPosition;
extern int tracePositions[2];
extern int selectedTrace;
extern int connectionIndex;
extern int activeTraces;
extern int selectedNode;
extern gameStatus currentStatus;
extern playerTurn currentTurn;
extern gameResult result;
extern defenderUIState defenderState;
extern float cameraX;
extern float cameraY;
extern int nodeRadius;
extern unsigned long gameOverTimestamp;
extern int mapNodeCount;
extern int selectedMap;

// ─── Defender Tools ──────────────────────────────────────
extern int nodeLockUsage;
extern DefenderTool activeTool;
extern int toolIndex;
extern bool toolConfirmed;
extern bool pingScanActive;
extern bool pingScanCooldown;
extern int pingScanRevealTurns;
extern int pingScanUsage;
extern bool speedBoostActive;
extern int speedBoostUsage;
extern int speedBoostDuration;
extern bool speedBoostMoveOne;

// ─── Hacker Tools ────────────────────────────────────────
extern bool hackerSpoofActive;
extern int spoofedHackerPosition;
extern int spoofTurnsRemaining;

// ─── Test Mode ───────────────────────────────────────────
extern bool testMode;
extern int testPath[7];
extern int testPathIndex;
extern unsigned long lastTestMoveMs;
extern unsigned long testMoveInterval;

// ─── BLE State ───────────────────────────────────────────
extern bool deviceConnected;
extern bool gameOverNotified;

// ─── Functions ───────────────────────────────────────────
void initializeTraces();
void resetGame();
