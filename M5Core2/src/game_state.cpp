#include "game_state.h"
#include "gameplay.h"

// ─── Map Data ────────────────────────────────────────────
Node nodes[25];

// ─── Game State ──────────────────────────────────────────
int hackerPosition    = -1;
int tracePositions[2] = {-1, -1};
int selectedTrace     = 0;
int connectionIndex   = -1;
int activeTraces      = 0;
int selectedNode      = -1;
gameStatus currentStatus   = WAITING_TO_CONNECT;
playerTurn currentTurn     = DEFENDER_TURN;
gameResult result          = NONE_RESULT;
defenderUIState defenderState = MAP_VIEW;
float cameraX = 290;
float cameraY = 130;
int nodeRadius = 0;
int spoofTurnsRemaining = 0;
unsigned long gameOverTimestamp = 0;
int selectedMap = 0;
int mapNodeCount = 24;


// ─── Defender Tools ──────────────────────────────────────
int nodeLockUsage     = 3;
DefenderTool activeTool = TOOL_NODELOCK;
int toolIndex         = 0;
bool toolConfirmed    = false;
bool pingScanActive   = false;
bool pingScanCooldown = false;
int pingScanRevealTurns = 0;
int pingScanUsage     = 3;
bool speedBoostActive = false;
int speedBoostUsage   = 2;
int speedBoostDuration = 0;
bool speedBoostMoveOne = false;

// ─── Hacker Tools ────────────────────────────────────────
bool hackerSpoofActive    = false;
int spoofedHackerPosition = -1;

// ─── Test Mode ───────────────────────────────────────────
bool testMode              = false;
int testPath[7]            = {0, 4, 7, 9, 13, 15, 23};
int testPathIndex          = 0;
unsigned long lastTestMoveMs   = 0;
unsigned long testMoveInterval = 3000;

// ─── BLE State ───────────────────────────────────────────
bool deviceConnected  = false;
bool gameOverNotified = false;

// ─── Leaderboard State ───────────────────────────────────────────
bool leaderboardPostDone = false;
bool leaderboardFetched  = false;

// ─── makeNode ────────────────────────────────────────────
Node makeNode(int id, float x, float y, NodeType type, int conns[], int connCount) {
    Node n;
    n.id = id;
    n.worldX = x;
    n.worldY = y;
    n.type = type;
    n.occupant = NONE;
    n.traceCount = 0;
    n.isLocked = false;
    n.connectionCount = connCount;
    for (int i = 0; i < connCount; i++) n.connections[i] = conns[i];
    return n;
}

void initializeTraces() {
    // For map1: nodes 9-22, for map2: nodes 7-23 (avoid entries, junctions, core)
    int minNode = (selectedMap == 0) ? 9  : 7;
    int maxNode = (selectedMap == 0) ? 22 : 23;

    int randomNode = random(minNode, maxNode);
    tracePositions[0] = randomNode;
    nodes[randomNode].traceCount++;
    nodes[randomNode].occupant = TRACE;

    while (tracePositions[1] == -1) {
        randomNode = random(minNode, maxNode);
        if (randomNode != tracePositions[0]) {
            tracePositions[1] = randomNode;
            nodes[randomNode].traceCount++;
            nodes[randomNode].occupant = TRACE;
        }
    }
}

// ─── resetGame ───────────────────────────────────────────
void resetGame() {
    hackerPosition     = -1;
    tracePositions[0]  = -1;
    tracePositions[1]  = -1;
    activeTraces       = 0;
    selectedNode       = -1;
    speedBoostUsage    = 2;
    speedBoostDuration = 0;
    nodeLockUsage      = 3;
    pingScanUsage      = 3;
    currentTurn        = DEFENDER_TURN;
    currentStatus      = MAP_SELECT;
    gameOverNotified   = false;
    result             = NONE_RESULT;
    activeTool         = TOOL_NODELOCK;
    toolIndex          = 0;
    toolConfirmed      = false;
    pingScanActive     = false;
    pingScanCooldown   = false;
    pingScanRevealTurns = 0;
    speedBoostActive   = false;
    speedBoostMoveOne  = false;
    hackerSpoofActive  = false;
    spoofedHackerPosition = -1;
    spoofTurnsRemaining = 0;
    gameOverTimestamp = 0;

    for (int i = 0; i < mapNodeCount; i++) {
        nodes[i].occupant   = NONE;
        nodes[i].traceCount = 0;
        nodes[i].isLocked   = false;
    }

    Serial.println("[SERVER] Reset Game!");
}
