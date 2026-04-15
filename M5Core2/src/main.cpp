#include <Arduino.h>
#include <M5Core2.h>
#include <Adafruit_seesaw.h>
#include <EEPROM.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

//////////////////////////////////////////////////////
// Shared BLE Protocol (must match client)
//////////////////////////////////////////////////////
static BLEUUID SERVICE_UUID("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
static BLEUUID CHAR_DEFENDER_UUID("beb5483e-36e1-4688-b7f5-ea07361b26a8");
static BLEUUID CHAR_HACKER_UUID ("beb5483e-36e1-4688-b7f5-ea07361b26a9");
static const char *SERVER_NAME = "HACKER_DEFENDER_GAME";

///////////////////////////////////////////////////////////////
// BLE Server State
///////////////////////////////////////////////////////////////
BLEServer* bleServer = nullptr;
BLEService* bleService = nullptr; 
BLECharacteristic* defenderChar = nullptr;
BLECharacteristic* hackerChar = nullptr;
bool deviceConnected = false;

//////////////////////////////////////////////////////
// Sprite Decleration
//////////////////////////////////////////////////////
TFT_eSprite sprite = TFT_eSprite(&M5.Lcd);

//////////////////////////////////////////////////////
// Gamepad QT configurations
//////////////////////////////////////////////////////
Adafruit_seesaw gamepad;
#define BUTTON_X  6
#define BUTTON_Y  2
#define BUTTON_A  5
#define BUTTON_B  1
#define BUTTON_START 16
#define BUTTON_SELECT 0
uint32_t button_mask = (1UL << BUTTON_X) | (1UL << BUTTON_Y) | 
                       (1UL << BUTTON_START) | (1UL << BUTTON_A) | 
                       (1UL << BUTTON_B) | (1UL << BUTTON_SELECT);

enum NodeType { NORMAL, ENTRY, JUNCTION, CORE };
enum Occupant { NONE, HACKER, TRACE };

//////////////////////////////////////////////////////
// Node Struct for individual nodes
//////////////////////////////////////////////////////
struct Node  {
  int id;
  float worldX, worldY;
  NodeType type;  // ENTRY, JUNCTION, CORE, NORMAL
  Occupant occupant = NONE;  // NONE, HACKER
  int traceCount = 0; // how many traces are here
  bool isLocked = false;
  int connections[6];  // adjacent node IDs
  int connectionCount = 0;
};

//////////////////////////////////////////////////////
// Function Declerations
//////////////////////////////////////////////////////
Node makeNode(int id, float x, float y, NodeType type, int conns[], int connCount);
void drawScreen();
void initializeTraces();

// Handles the different states of the game
void handleWaitingToConnect();
void handleHackerSelect();
void handleGameplay();
void handleGameOver();
void resetGame(); 

// Handles switching between player turns
void handleHackerTurn();
void handleDefenderTurn();

// BLE functions
void startBleServer();
void restartAdvertising();
void sendDefenderState();

//////////////////////////////////////////////////////
// Variable Declarations
//////////////////////////////////////////////////////
Node nodes[24];

int hackerPosition = -1; // Hackers current position
int tracePositions[2] = {-1, -1}; // Array containing the positions of the tracers
int selectedTrace = 0; // which trace (0 or 1) is being moved
int connectionIndex = -1; // Index that helps cycle through neighboring nodes
int activeTraces = 0; // Count of how many active traces
int selectedNode = -1; // Selected Node to make an action on
int nodeLockUsage = 3; // Count of how many nodes can be locked
bool gameOverNotified = false; // Notifies client that game is over

// Tool select state
enum DefenderTool { TOOL_NODELOCK, TOOL_SPEEDBOOST, TOOL_PINGSCAN };
DefenderTool activeTool = TOOL_NODELOCK;
int toolIndex = 0; // cycles through available tools
bool toolConfirmed = false;

// Ping scan state
bool pingScanActive = false;
bool pingScanCooldown = false;
int pingScanRevealTurns = 0;
int pingScanUsage = 3; // Number of ping scans left

// Speed boost state  
bool speedBoostActive = false;
int speedBoostUsage = 2; // Count of how many speed boosts left
int speedBoostDuration = 0; // Count of how long the speed boost is active for
// Speed boost move tracking
bool speedBoostMoveOne = false; // true after first move, waiting for second

// Hacker tools
bool hackerSpoofActive = false;
int spoofedHackerPosition = -1; // used when spoof is active

//////////////////////////////////////////////////////
// Test Variable Declarations
//////////////////////////////////////////////////////
bool testMode = true; // set to false for real game
int testPath[] = {0, 4, 7, 9, 13, 15, 23}; // path to CORE
int testPathIndex = 0;
unsigned long lastTestMoveMs = 0;
unsigned long testMoveInterval = 3000; // move every 3 seconds

enum gameStatus { WAITING_TO_CONNECT, HACKER_SELECT, GAME_IN_PROGRESS, GAME_OVER };
// Should be WAITING_TO_CONNECT so screen will show a "lobby" waiting for player
gameStatus currentStatus = WAITING_TO_CONNECT;
enum playerTurn { HACKER_TURN, DEFENDER_TURN };
playerTurn currentTurn = DEFENDER_TURN;
enum gameResult { NONE_RESULT, HACKER_WIN, DEFENDER_WIN };
gameResult result = NONE_RESULT;

enum defenderUIState { 
    MAP_VIEW,      // free roam, joystick pans camera
    NODE_SELECT,   // selecting which node to move trace to
    TOOL_SELECT    // selecting which tool to use
};
defenderUIState defenderState = MAP_VIEW;

// Junction is in the center of the screen
float cameraX = 290;
float cameraY = 130;

// Core is in the center of screen
// float cameraX = 290; 
// float cameraY = 320;

int nodeRadius;

//////////////////////////////////////////////////////
// Contrsutor function to create a node
//////////////////////////////////////////////////////
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
  for(int i = 0; i < connCount; i++) {
    n.connections[i] = conns[i];
  }
  return n;
}

uint32_t getNodeColor(NodeType type) {
  switch(type) {
      case ENTRY:    return TFT_YELLOW;
      case NORMAL:   return TFT_GREEN;
      case JUNCTION: return TFT_CYAN;
      case CORE:     return TFT_RED;
      default:       return TFT_GREEN;
  }
}

int getNodeRadius(NodeType type) {
    switch(type) {
        case ENTRY:    return 6;
        case NORMAL:   return 4;
        case JUNCTION: return 8;
        case CORE:     return 10;
        default:       return 4;
    }
}

///////////////////////////////////////////////////////////////
// BLE Callbacks
///////////////////////////////////////////////////////////////
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) override {
    (void)pServer;
    deviceConnected = true;
    currentStatus = HACKER_SELECT;
    Serial.println("[SERVER] Client connected!");
  }

  void onDisconnect(BLEServer *pServer) override {
    (void)pServer;
    deviceConnected = false;
    currentStatus = WAITING_TO_CONNECT;
    // Create a function to restart advertising for a reconnect
    restartAdvertising();
  }
};

class HackerWriteCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) override {
    String uuid = pCharacteristic->getUUID().toString().c_str();
    String value = pCharacteristic->getValue().c_str();

    // Check if we get the hacker's UUID
    if(!uuid.equalsIgnoreCase(CHAR_HACKER_UUID.toString().c_str())) {
      return;
    }

    // Extract ID after "N"
    int pipeIndex = value.lastIndexOf('|');
    int nodeId = value.substring(1, pipeIndex).toInt();

    // Extract tool after "TOOL:"
    String tool = value.substring(value.indexOf(':') + 1);

    // Update game state
    hackerPosition = nodeId;
    Serial.printf("[SERVER] Hacker moved to node: %d\n", hackerPosition);
    Serial.printf("[SERVER] Full payload received: %s\n", value.c_str());

    // Check if Hacker made it to Core node
    if(nodes[hackerPosition].type == CORE ) {
      result = HACKER_WIN;
      currentStatus = GAME_OVER;
      Serial.println("[SERVER] Hacker reached CORE — Hacker wins!");
    }

    // Check if Hacker moved onto a trace
    if(tracePositions[0] == hackerPosition || tracePositions[1] == hackerPosition) {
        result = DEFENDER_WIN;
        currentStatus = GAME_OVER;
        Serial.println("[SERVER] DEFENDER WIN - hacker walked into trace");
    }

    // Chnage to Defender's turn
    currentTurn = DEFENDER_TURN;

    // Parse tool — format is "toolname" or "toolname:targetNode"
    if (tool != "none") {
        int colonIdx = tool.indexOf(':');
        String toolName = (colonIdx >= 0) ? tool.substring(0, colonIdx) : tool;
        int toolTarget = (colonIdx >= 0) ? tool.substring(colonIdx + 1).toInt() : -1;

        Serial.printf("[SERVER] Tool used: %s target: %d\n", toolName.c_str(), toolTarget);

        if (toolName == "crack" && toolTarget >= 0) {
            // Unlock the target node
            nodes[toolTarget].isLocked = false;
            Serial.printf("[SERVER] Node %d unlocked by Crack\n", toolTarget);

        } else if (toolName == "tunnel" && toolTarget >= 0 && toolTarget <= 3) {
            // Move hacker to entry node
            if (hackerPosition >= 0) nodes[hackerPosition].occupant = NONE;
            hackerPosition = toolTarget;
            nodes[hackerPosition].occupant = HACKER;
            Serial.printf("[SERVER] Hacker tunneled to entry node %d\n", hackerPosition);

        } else if (toolName == "spoof") {
            hackerSpoofActive = true;
            Serial.println("[SERVER] Spoof activated");
        }
    }
  }
};

void drawScreen() {
  sprite.fillScreen(TFT_BLACK);
  
  if(currentStatus == WAITING_TO_CONNECT) {
    sprite.setTextSize(2);

    for(int i = 0; i < 10; i++) {
      int x = random(0, 320);
      int y = random(0, 240);
      sprite.setCursor(x, y);
      sprite.print(random(0, 2));
    }

    for(int i = 0; i < 15; i++) {
      sprite.setTextColor(TFT_DARKGREEN);
      sprite.setCursor(random(0, 320), random(0, 240));
      sprite.print(random(0, 2));
    }

    sprite.setTextColor(TFT_GREEN, TFT_BLACK);
    sprite.setCursor(40, 80);
    sprite.print("INITIALIZING...");
    sprite.setCursor(20, 110);
    sprite.print("AWAITING CONNECTION");

    int dots = (millis() / 500) % 4;
    sprite.setCursor(260, 110);
    for(int i = 0; i < dots; i++) sprite.print(".");

    sprite.drawRect(10, 180, 300, 20, TFT_GREEN);
    int progress = (millis() / 50) % 300;
    sprite.fillRect(10, 180, progress, 20, TFT_GREEN);

  } else if (currentStatus == GAME_OVER) {
    bool blink = (millis() / 400) % 2;
    sprite.setTextSize(2);

    if(result == HACKER_WIN) {
      sprite.setTextColor(blink ? TFT_RED : TFT_DARKGREY);
      sprite.setCursor(40, 60);
      sprite.print("CORE BREACHED");
      sprite.setTextColor(TFT_RED);
      sprite.setCursor(30, 100);
      sprite.print("SYSTEM FAILURE");
      sprite.setTextSize(1);
      sprite.setCursor(20, 140);
      sprite.print("> ROOT ACCESS GRANTED");
    } else if(result == DEFENDER_WIN) {
      sprite.setTextColor(blink ? TFT_GREEN : TFT_DARKGREEN);
      sprite.setCursor(40, 60);
      sprite.print("TRACE COMPLETE");
      sprite.setTextColor(TFT_GREEN);
      sprite.setCursor(20, 100);
      sprite.print("INTRUDER ELIMINATED");
      sprite.setTextSize(1);
      sprite.setCursor(20, 140);
      sprite.print("> SYSTEM SECURED");
    }

    sprite.setTextSize(1);
    sprite.setTextColor(TFT_WHITE);
    sprite.setCursor(40, 200);
    sprite.print("Press A to reboot");

    if (M5.BtnA.wasPressed()) resetGame();

  } else if(currentStatus == HACKER_SELECT) {
    sprite.setTextColor(TFT_GREEN, TFT_BLACK);
    sprite.setTextSize(2);
    sprite.setCursor(20, 100);
    sprite.print("Waiting for Hacker...");

  } else {
    ////////////////////////////////////////////////////////////////
    // PASS 1 — Draw all edges regardless of viewport
    ////////////////////////////////////////////////////////////////
    for (int i = 0; i < 24; i++) {
      for (int j = 0; j < nodes[i].connectionCount; j++) {
        int connectingNodeId = nodes[i].connections[j];
        if (connectingNodeId > i) { // draw each edge only once
          int x1 = (int)(nodes[i].worldX - cameraX);
          int y1 = (int)(nodes[i].worldY - cameraY);
          int x2 = (int)(nodes[connectingNodeId].worldX - cameraX);
          int y2 = (int)(nodes[connectingNodeId].worldY - cameraY);
          sprite.drawLine(x1, y1, x2, y2, TFT_DARKGREY);
        }
      }
    }

    ////////////////////////////////////////////////////////////////
    // PASS 2 — Draw nodes only when in viewport
    ////////////////////////////////////////////////////////////////
    for (int i = 0; i < 24; i++) {
      Node currentNode = nodes[i];
      int screenX = (int)(currentNode.worldX - cameraX);
      int screenY = (int)(currentNode.worldY - cameraY);

      if (screenX >= 0 && screenX <= 320 && screenY >= 18 && screenY <= 210) {

        uint32_t nodeColor = getNodeColor(currentNode.type);
        nodeRadius = getNodeRadius(currentNode.type);

        sprite.fillCircle(screenX, screenY, nodeRadius, nodeColor);

        // Lock indicator
        if (currentNode.isLocked) {
          sprite.fillRect(screenX - 4, screenY - nodeRadius - 8, 8, 6, TFT_ORANGE);
          sprite.drawLine(screenX - 2, screenY - nodeRadius - 8,
                          screenX - 2, screenY - nodeRadius - 11, TFT_ORANGE);
          sprite.drawLine(screenX + 2, screenY - nodeRadius - 8,
                          screenX + 2, screenY - nodeRadius - 11, TFT_ORANGE);
          sprite.drawLine(screenX - 2, screenY - nodeRadius - 11,
                          screenX + 2, screenY - nodeRadius - 11, TFT_ORANGE);
          sprite.drawCircle(screenX, screenY, nodeRadius + 2, TFT_ORANGE);
        }

        // Hacker location in testMode
        if (i == hackerPosition && testMode) {
          sprite.fillCircle(screenX, screenY, nodeRadius - 2, TFT_PINK);
        }

        // Trace indicator
        if(currentNode.traceCount > 0) {
          sprite.fillCircle(screenX, screenY, nodeRadius - 2, TFT_PURPLE);
        }

        // Selection highlight
        if (i == selectedNode && currentNode.traceCount > 0) {
          sprite.fillCircle(screenX, screenY, nodeRadius, TFT_PURPLE);
        } else if (i == selectedNode) {
          sprite.drawCircle(screenX, screenY, nodeRadius + 4, TFT_WHITE);
        }
      }
    }

    ////////////////////////////////////////////////////////////////
    // TOP STATUS BAR
    ////////////////////////////////////////////////////////////////
    sprite.fillRect(0, 0, 320, 18, 0x1082);
    sprite.drawFastHLine(0, 18, 320, TFT_CYAN);
    sprite.setTextSize(1);

    if (currentTurn == DEFENDER_TURN) {
      sprite.setTextColor(TFT_GREEN);
      sprite.setCursor(4, 5);
      sprite.print("DEFENDER TURN");
    } else {
      sprite.setTextColor(TFT_RED);
      sprite.setCursor(4, 5);
      sprite.print("HACKER TURN");
    }

    sprite.setTextColor(TFT_CYAN);
    sprite.setCursor(110, 5);
    if (defenderState == MAP_VIEW)        sprite.print("[ MAP VIEW ]");
    else if (defenderState == NODE_SELECT) sprite.print("[ NODE SEL ]");
    else if (defenderState == TOOL_SELECT) sprite.print("[ TOOLS ]");

    sprite.setTextColor(TFT_WHITE);
    sprite.setCursor(240, 5);
    sprite.printf("L:%d S:%d P:%d", nodeLockUsage, speedBoostUsage, pingScanUsage);

    ////////////////////////////////////////////////////////////////
    // BOTTOM HUD — NODE SELECT
    ////////////////////////////////////////////////////////////////
    if(defenderState == NODE_SELECT) {
      sprite.fillRect(0, 210, 320, 30, TFT_DARKGREY);
      sprite.setCursor(5, 218);
      if (speedBoostActive && speedBoostMoveOne) {
        sprite.setTextColor(TFT_YELLOW);
        sprite.printf("BOOST! T%d < Node %d > B:2nd Move", selectedTrace, selectedNode);
      } else if (speedBoostActive) {
        sprite.setTextColor(TFT_YELLOW);
        sprite.printf("BOOST! T%d < Node %d > B:1st Move", selectedTrace, selectedNode);
      } else if (nodes[selectedNode].isLocked) {
        sprite.setTextColor(TFT_ORANGE);
        sprite.printf("T%d < Node %d > LOCKED!", selectedTrace, selectedNode);
      } else {
        sprite.setTextColor(TFT_WHITE);
        sprite.printf("T%d < Node %d > B:Move | Y:Switch", selectedTrace, selectedNode);
      }
    }

    ////////////////////////////////////////////////////////////////
    // BOTTOM HUD — TOOL SELECT
    ////////////////////////////////////////////////////////////////
    if (defenderState == TOOL_SELECT) {
      sprite.fillRect(0, 195, 320, 45, TFT_BLACK);
      sprite.drawRect(0, 195, 320, 45, TFT_CYAN);

      const char* toolNames[] = {"NODE LOCK", "SPEED BOOST", "PING SCAN"};
      int toolUsages[] = {nodeLockUsage, speedBoostUsage, pingScanUsage};

      sprite.setTextSize(1);

      if (toolConfirmed) {
        sprite.setTextColor(TFT_RED);
        sprite.setCursor(40, 200);
        sprite.printf("LOCKING NODE %d", selectedNode);
        sprite.setTextColor(TFT_WHITE);
        sprite.setCursor(40, 212);
        sprite.print("< > cycle  B: Lock  SELECT: Cancel");
      } else {
        sprite.setTextColor(TFT_CYAN);
        sprite.setCursor(4, 205);
        sprite.print("<");
        sprite.setCursor(312, 205);
        sprite.print(">");
        sprite.setTextColor(TFT_YELLOW);
        sprite.setCursor(60, 200);
        sprite.printf("[ %s ]", toolNames[toolIndex]);
        sprite.setTextColor(TFT_WHITE);
        sprite.setCursor(60, 212);
        sprite.printf("Uses left: %d", toolUsages[toolIndex]);
        sprite.setTextColor(TFT_GREEN);
        sprite.setCursor(60, 224);
        sprite.print("START: Use  SELECT: Back");
      }
    }

    ////////////////////////////////////////////////////////////////
    // PING SCAN PULSE — drawn last so it's on top
    ////////////////////////////////////////////////////////////////
    if (pingScanActive && hackerPosition >= 0) {
      int pingTarget = (spoofedHackerPosition >= 0) ? spoofedHackerPosition : hackerPosition;
      Node pingNode = nodes[pingTarget];
      int hScreenX = (int)(pingNode.worldX - cameraX);
      int hScreenY = (int)(pingNode.worldY - cameraY);

      if (hScreenX >= -20 && hScreenX <= 340 && hScreenY >= -20 && hScreenY <= 260) {
        float pulse = sin(millis() / 150.0f);
        int pulseRadius = 16 + (int)(pulse * 6);
        sprite.drawCircle(hScreenX, hScreenY, pulseRadius, TFT_RED);
        sprite.drawCircle(hScreenX, hScreenY, pulseRadius + 3, TFT_RED);
        sprite.drawCircle(hScreenX, hScreenY, pulseRadius + 6, 0x7800);
      }
    }
  }

  sprite.pushSprite(0, 0);
}

// Initializes traces randomly
// Never initializes the tracs on the same node, low level nodes, entry nodes, or core node
void initializeTraces() {
  int randomNode = random(9, 22);

  tracePositions[0] = randomNode;
  nodes[randomNode].traceCount++;
  nodes[randomNode].occupant = TRACE;
  randomNode = random(9, 22);

  while (tracePositions[1] == -1) {
    if (randomNode == tracePositions[0]) {
      randomNode = random(9, 22);
    } else {
      tracePositions[1] = randomNode;
      nodes[randomNode].traceCount++;
      nodes[randomNode].occupant = TRACE;
    }
  }

}

void setup() {
  
  M5.begin();

  if (!gamepad.begin(0x50)) {
    Serial.print("Seesaw not found");
    while(1);
  }

  gamepad.pinModeBulk(button_mask, INPUT_PULLUP);
  gamepad.setGPIOInterrupts(button_mask, 1);

  // Sprite frame Generator
  sprite.createSprite(320, 240);

  // Random seed generator
  int seedAddress = 0;
  long seed = EEPROM.read(seedAddress);
  randomSeed(seed);
  EEPROM.write(seedAddress, seed+ 1);

  //////////////////////////////////////////////////////
  // Initialize the arrays of connecting nodes
  //////////////////////////////////////////////////////
  int c0[] = {4, 6}; 
  int c1[] = {5, 8}; 
  int c2[] = {6, 11}; 
  int c3[] = {8, 12}; 
  int c4[] = {0, 6, 7}; 
  int c5[] = {1, 7, 8}; 
  int c6[] = {0, 2, 4, 9, 11}; 
  int c7[] = {4, 5, 9, 10}; 
  int c8[] = {1, 3, 5, 10, 12}; 
  int c9[] = {6, 7, 13, 15}; 
  int c10[] = {7, 8, 14, 15}; 
  int c11[] = {2, 6, 13, 16}; 
  int c12[] = {3, 8, 14, 17}; 
  int c13[] = {9, 11, 15, 18}; 
  int c14[] = {10, 12, 15, 19}; 
  int c15[] = {9, 10, 13, 14, 23}; 
  int c16[] = {11, 18, 20}; 
  int c17[] = {12, 19, 21}; 
  int c18[] = {13, 16, 22}; 
  int c19[] = {14, 17, 22}; 
  int c20[] = {16, 22, 23}; 
  int c21[] = {17, 22, 23};
  int c22[] = {18, 19, 20, 21, 23};
  int c23[] = {15, 20, 21, 22};

  //////////////////////////////////////////////////////
  // Make and configure each node
  //////////////////////////////////////////////////////
  nodes[0] = makeNode(0, 80, 800, ENTRY, c0, 2);
  nodes[1] = makeNode(1, 820, 800, ENTRY, c1, 2);
  nodes[2] = makeNode(2, 80, 100, ENTRY, c2, 2);
  nodes[3] = makeNode(3, 820, 100, ENTRY, c3, 2);
  nodes[4] = makeNode(4, 200, 700, NORMAL, c4, 3);
  nodes[5] = makeNode(5, 700, 700, NORMAL, c5, 3);
  nodes[6] = makeNode(6, 150, 550, NORMAL, c6, 5);
  nodes[7] = makeNode(7, 450, 650, NORMAL, c7, 4);
  nodes[8] = makeNode(8, 750, 550, NORMAL, c8, 5);
  nodes[9] = makeNode(9, 300, 480, NORMAL, c9, 4);
  nodes[10] = makeNode(10, 600, 480, NORMAL, c10, 4);
  nodes[11] = makeNode(11, 100, 380, NORMAL, c11, 4);
  nodes[12] = makeNode(12, 800, 380, NORMAL, c12, 4);
  nodes[13] = makeNode(13, 250, 300, NORMAL, c13, 4);
  nodes[14] = makeNode(14, 650, 300, NORMAL, c14, 4);
  nodes[15] = makeNode(15, 450, 350, JUNCTION, c15, 5);
  nodes[16] = makeNode(16, 150, 200, NORMAL, c16, 3);
  nodes[17] = makeNode(17, 750, 200, NORMAL, c17, 3);
  nodes[18] = makeNode(18, 350, 220, NORMAL, c18, 3);
  nodes[19] = makeNode(19, 550, 220, NORMAL, c19, 3);
  nodes[20] = makeNode(20, 250, 120, NORMAL, c20, 3);
  nodes[21] = makeNode(21, 650, 120, NORMAL, c21, 3);
  nodes[22] = makeNode(22, 450, 160, NORMAL, c22, 5);
  nodes[23] = makeNode(23, 450, 450, CORE, c23, 4);

  BLEDevice::init(SERVER_NAME);
  startBleServer();

}

void loop() {
  switch(currentStatus) {
    case WAITING_TO_CONNECT:   handleWaitingToConnect(); break;
    case HACKER_SELECT:       handleHackerSelect(); break;
    case GAME_IN_PROGRESS:    handleGameplay(); break;
    case GAME_OVER:           handleGameOver(); break;
  }
  drawScreen();

}

///////////////////////////////////////////////////////////////
// BLE setup
///////////////////////////////////////////////////////////////
void startBleServer() {
  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new ServerCallbacks());

  bleService = bleServer->createService(SERVICE_UUID);

  defenderChar = bleService->createCharacteristic(
    CHAR_DEFENDER_UUID,
    BLECharacteristic::PROPERTY_READ |
      BLECharacteristic::PROPERTY_NOTIFY |
      BLECharacteristic::PROPERTY_INDICATE);
  defenderChar->addDescriptor(new BLE2902());
  defenderChar->setValue("240-120");

  hackerChar = bleService->createCharacteristic(
    CHAR_HACKER_UUID,
    BLECharacteristic::PROPERTY_WRITE);
  hackerChar->setCallbacks(new HackerWriteCallbacks());

  bleService->start();
  restartAdvertising();
}

void restartAdvertising() {
  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->stop();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  advertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.println("[SERVER] Advertising started.");
}

void sendDefenderState() {
  Serial.printf("[SERVER] sendDefenderState called — connected:%d\n", deviceConnected);
  if(!deviceConnected || defenderChar == nullptr) return;

  // Build trace positions string
  String payload = "T" + String(tracePositions[0]) +
                   "," + String(tracePositions[1]);

  // Add locked node (-1 if none locked)
  int lockedNode = -1;
  for (int i = 0; i < 24; i++) {
    if (nodes[i].isLocked) {
      lockedNode = i;
      break;
    }
  }
  payload += "|L" + String(lockedNode);
  payload += pingScanActive ? "|P1" : "|P0";

  // Add game status
  if(currentStatus == GAME_OVER) {
    if(result == DEFENDER_WIN) {
      payload += "|SWIN"; // Defender wins
    } else if(result == HACKER_WIN) {
      payload += "|HWIN";
    }
  } else {
    payload += "|SPLAY";
  }

  defenderChar->setValue(payload.c_str());
  defenderChar->notify();

  Serial.printf("[SERVER] Sent: %s\n", payload.c_str());
}

//////////////////////////////////////////////////////
// Functions that handle the different states of the game
//////////////////////////////////////////////////////
void handleWaitingToConnect() {
  if (testMode) {
      currentStatus = HACKER_SELECT;
  }
}

void handleHackerSelect() {
  if (testMode && hackerPosition == -1) {
        hackerPosition = testPath[0];
        testPathIndex = 1;
        initializeTraces();
        nodes[hackerPosition].occupant = HACKER;
        currentStatus = GAME_IN_PROGRESS;
        return;
    }

  if(hackerPosition != -1) {
    Serial.printf("[SERVER] Hacker selected entry node: %d\n", hackerPosition);
    initializeTraces();
    nodes[hackerPosition].occupant = HACKER;
    currentStatus = GAME_IN_PROGRESS;
  }
}

void handleGameplay() {
  switch(currentTurn) {
    case HACKER_TURN: handleHackerTurn(); break;
    case DEFENDER_TURN: handleDefenderTurn(); break;
  }
}

// Need to move the display logic into drawScreen function to have all display logic into one function
// Needs to check the status of the game and draw screen based off that check
void handleGameOver() {
  if(!gameOverNotified) {
    sendDefenderState();
    gameOverNotified = true;
  }

  //  if (M5.BtnA.wasPressed()) {
  //     resetGame();
  //   }
}


//////////////////////////////////////////////////////
// Functions that run depending on whose turn it is
//////////////////////////////////////////////////////

void handleHackerTurn() {
  if (!testMode) return; // real game waits for BLE

    unsigned long now = millis();
    if (now - lastTestMoveMs < testMoveInterval) return;
    lastTestMoveMs = now;

    if (testPathIndex < 7) {
        // Move hacker to next node in test path
        int oldPos = hackerPosition;
        hackerPosition = testPath[testPathIndex];
        testPathIndex++;

        // Update node occupants
        if (oldPos >= 0) nodes[oldPos].occupant = NONE;
        nodes[hackerPosition].occupant = HACKER;

        Serial.printf("[TEST] Hacker auto-moved to node: %d\n", hackerPosition);

        // Check win conditions
        if (nodes[hackerPosition].type == CORE) {
            result = HACKER_WIN;
            currentStatus = GAME_OVER;
        }
        if (tracePositions[0] == hackerPosition || 
            tracePositions[1] == hackerPosition) {
            result = DEFENDER_WIN;
            currentStatus = GAME_OVER;
        }

        // Switch to defender turn
        currentTurn = DEFENDER_TURN;

        if (pingScanActive) {
            pingScanRevealTurns--;
            if (pingScanRevealTurns <= 0) {
                pingScanActive = false;
                pingScanCooldown = false;
            }
        }
    }
}

void handleDefenderTurn() {
  // Reads the inputs every frame 
  int joyX = 1023 - gamepad.analogRead(14);
  int joyY = gamepad.analogRead(15);

  // Trying to fix stick drift in MAP_VIEW
  int dx = joyX - 512;
  int dy = joyY - 512;

  int deadzone = 45;
  if (abs(dx) < deadzone) dx = 0;
  if (abs(dy) < deadzone) dy = 0;

  // Trying to invert the controls and fix map
  // int joyX = gamepad.analogRead(14);
  // int joyY = 1023 - gamepad.analogRead(15);

  uint32_t buttons = gamepad.digitalReadBulk(0xFFFFFFFF);

  // Joystick: check if pushed past a deadzone threshold
  bool pushingLeft = joyX < 412;
  bool pushingRight = joyX > 612;
  bool pushingUp = joyY < 412;
  bool pushingDown = joyY > 612;

  // Buttons: LOW means pressed (active low)
  bool startPressed = !(buttons & (1UL << BUTTON_START));
  bool selectPressed = !(buttons & (1UL << BUTTON_SELECT));
  bool bPressed = !(buttons & (1UL << BUTTON_B));
  bool yPressed = !(buttons & (1UL << BUTTON_Y));

  // Debounce for the buttons
  static bool lastStart = false;
  static bool lastSelect = false;
  static bool lastB = false;
  static bool lastY = false;

  // Debounce for the joystick
  static bool lastPushLeft = false;
  static bool lastPushRight = false;

  bool startJustPressed = startPressed && !lastStart;
  bool selectJustPressed = selectPressed && !lastSelect;
  bool bJustPressed = bPressed && !lastB;
  bool yJustPressed = yPressed && !lastY;

  bool leftJustPushed = pushingLeft && !lastPushLeft;
  bool rightJustPushed = pushingRight && !lastPushRight;
  
  static unsigned long lastDebounceTime = 0;
  unsigned long debounceDelay = 200; // ms

  if (startJustPressed || selectJustPressed || bJustPressed || 
      yJustPressed || leftJustPushed || rightJustPushed) {

      unsigned long now = millis();
      if (now - lastDebounceTime < debounceDelay) {
          // Too soon — ignore this press
          startJustPressed = false;
          selectJustPressed = false;
          bJustPressed = false;
          yJustPressed = false;
          leftJustPushed = false; 
          rightJustPushed = false;
      } else {
          lastDebounceTime = now;
      }
  }

  lastStart = startPressed;
  lastSelect = selectPressed;
  lastB = bPressed;
  lastY = yPressed;
  lastPushLeft = pushingLeft;
  lastPushRight = pushingRight;

  ////////////////////////////////////////////////////////////////
  // MAP VIEW MODE
  ////////////////////////////////////////////////////////////////
  if(defenderState == MAP_VIEW) {
    float speed = 0.1f;
    // Trying to invert the controls and fix map
    cameraX += dx * speed;
    cameraY += dy * speed;
    
    // Prevents the user from scrolling off the map
    cameraX = constrain(cameraX, 0, 580);
    cameraY = constrain(cameraY, 0, 660);

    ////////////////////////////////////////////////////////////////
    // GOES TO NODE SELECT MODE
    ////////////////////////////////////////////////////////////////
    if (startJustPressed) {

      // Check if traces have been initialized, if not initialize them
      if(tracePositions[0] == -1 && tracePositions[1] == -1) {
        initializeTraces();
      }

      // Initializes the nodes that are able to be highlighted
      connectionIndex = -1;
      // selectedNode = nodes[tracePositions[selectedTrace]].connectionCount - 1;

      defenderState = NODE_SELECT;
    } 

    ////////////////////////////////////////////////////////////////
    // GOES TO TOOL SELECT MODE
    ////////////////////////////////////////////////////////////////
    if (selectJustPressed) {
      defenderState = TOOL_SELECT;
    }

  ////////////////////////////////////////////////////////////////
  // TOOL SELECT MODE
  ////////////////////////////////////////////////////////////////
  } else if (defenderState == TOOL_SELECT) {

    if (!toolConfirmed) {
        // Cycle through tools
        if (rightJustPushed) {
            toolIndex = (toolIndex + 1) % 3;
            activeTool = (DefenderTool)toolIndex;
        }
        if (leftJustPushed) {
            toolIndex = (toolIndex + 2) % 3;
            activeTool = (DefenderTool)toolIndex;
        }

        // Activate tool with START
        if (startJustPressed) {
            if (activeTool == TOOL_NODELOCK && nodeLockUsage > 0) {
                toolConfirmed = true;
                connectionIndex = 0;
                selectedNode = 0; // start at node 0
            } else if (activeTool == TOOL_SPEEDBOOST && speedBoostUsage > 0) {
                speedBoostActive = true;
                speedBoostUsage--;
                sendDefenderState();
                currentTurn = HACKER_TURN;
                defenderState = MAP_VIEW;
            } else if (activeTool == TOOL_PINGSCAN && pingScanUsage > 0 && !pingScanCooldown) {
                pingScanActive = true;
                pingScanUsage--;
                pingScanCooldown = true;
                pingScanRevealTurns = 1;

                // If hacker has spoof active, pan to wrong node
                if (hackerSpoofActive) {
                    int fakeNode = random(0, 23);
                    while (fakeNode == hackerPosition) fakeNode = random(0, 23);
                    spoofedHackerPosition = fakeNode;
                    cameraX = nodes[fakeNode].worldX - 160;
                    cameraY = nodes[fakeNode].worldY - 120;
                    hackerSpoofActive = false;
                } else {
                    spoofedHackerPosition = -1; // no spoof, use real position
                    cameraX = nodes[hackerPosition].worldX - 160;
                    cameraY = nodes[hackerPosition].worldY - 120;
                }

                sendDefenderState();
                currentTurn = HACKER_TURN;
                defenderState = MAP_VIEW;
            }
        }
    } else {
        // toolConfirmed == true means Node Lock is active
        // Cycle through ALL 24 nodes
        if (rightJustPushed) {
            connectionIndex = (connectionIndex + 1) % 24;
            selectedNode = connectionIndex;
            // Pan camera to selected node
            cameraX = nodes[selectedNode].worldX - 160;
            cameraY = nodes[selectedNode].worldY - 120;
        }
        if (leftJustPushed) {
            connectionIndex = (connectionIndex + 23) % 24;
            selectedNode = connectionIndex;
            cameraX = nodes[selectedNode].worldX - 160;
            cameraY = nodes[selectedNode].worldY - 120;
        }

        // B confirms the lock
        if (bJustPressed) {
            if (!nodes[selectedNode].isLocked) {
                nodes[selectedNode].isLocked = true;
                nodeLockUsage--;
                toolConfirmed = false;
                sendDefenderState();
                currentTurn = HACKER_TURN;
                defenderState = MAP_VIEW;
            }
        }

        // Cancel with SELECT
        if (selectJustPressed) {
            toolConfirmed = false;
        }
    }

    // Back to MAP_VIEW with SELECT (only when not in node selection)
    if (selectJustPressed && !toolConfirmed) {
        defenderState = MAP_VIEW;
    }
  } else {

    // NEED TO BE ABLE TO VIEW THE SELECTED TRACES POSITION INSTEAD OF JUST THE NEIGHTBORING NODES

    // Sets the camera position to the selectedTrace's position 
    if(selectedNode == -1 && connectionIndex != -1) {
      // Reset camera position to center on the selectedTrace 
      cameraX = nodes[tracePositions[selectedTrace]].worldX - 160;
      cameraY = nodes[tracePositions[selectedTrace]].worldY - 120;
    } else if (selectedNode != -1) {
      // Sets the camera position to view the neighboring nodes/selectedNode
      cameraX = nodes[selectedNode].worldX - 160;
      cameraY = nodes[selectedNode].worldY - 120;
    }

    // Switch to view a different trace and see the connected nodes
    if(yJustPressed) {
      // Reset the connection index to prevent outofbounds scenario
      connectionIndex = -1;
      if(selectedTrace == 1) {
        selectedTrace = 0;
      } else {
        selectedTrace ++;
      }
      // Change camera position based off of selected trace
      cameraX = nodes[tracePositions[selectedTrace]].worldX - 160;
      cameraY = nodes[tracePositions[selectedTrace]].worldY - 120;
    }

    // Increment the connectionIndex to cycle through connecting nodes
    if(rightJustPushed) {
      // Check to wrap around the nodes array size
      if(connectionIndex != nodes[tracePositions[selectedTrace]].connectionCount - 1) {
        connectionIndex++;
      } else {
        connectionIndex = -1;
      }
    } 

    // Decrement the connectionIndex to cycle through connecting nodes
    if(leftJustPushed) {
      // Check to wrap around the nodes array size
      if(connectionIndex != -1) {
        connectionIndex--; 
      } else {
        connectionIndex = nodes[tracePositions[selectedTrace]].connectionCount - 1;
      }
    }

    // Update selectedNode to one of the neighboring nodes to selectedTrace's node
    if(connectionIndex == -1) {
      selectedNode = tracePositions[selectedTrace];
    } else {
      selectedNode = nodes[tracePositions[selectedTrace]].connections[connectionIndex];
    }

    // If B was pressed, move trace position to selected node and end turn
    //////////////////////////////////////////////
    // B PRESSED: Confirms action with checks
    //            to verify if action id valid
    /////////////////////////////////////////////
    if(bJustPressed) {

      if (connectionIndex == -1) {
        // Can not confirm no neighbor selected yet

      } else if (nodes[selectedNode].isLocked) {
        // Check to see if desired destination node is locked before allowing move
        // Display warning text that says "Cannot move. Node is locked"

      } else {
        // Move the trace
        nodes[tracePositions[selectedTrace]].traceCount--;
        nodes[tracePositions[selectedTrace]].occupant = NONE;
        tracePositions[selectedTrace] = selectedNode;

        // Check win condition after first move
        if (tracePositions[selectedTrace] == hackerPosition) {
          result = DEFENDER_WIN;
          currentStatus = GAME_OVER;
          sendDefenderState();
          currentTurn = HACKER_TURN;
          defenderState = MAP_VIEW;
          speedBoostMoveOne = false;
          speedBoostActive = false;
        } else {
          nodes[tracePositions[selectedTrace]].traceCount++;
          nodes[tracePositions[selectedTrace]].occupant = TRACE;

          if (speedBoostActive && !speedBoostMoveOne) {
            // First move done — reset for second move
            speedBoostMoveOne = true;
            connectionIndex = -1;
            // Stay in NODE_SELECT, same trace
          } else {
            // Normal end of turn (or second speed boost move)
            sendDefenderState();
            currentTurn = HACKER_TURN;
            defenderState = MAP_VIEW;
            speedBoostMoveOne = false;
            speedBoostActive = false;
          }
        }
      }
    }

    ////////////////////////////////////////////////////////////////
    // RETURNS TO MAP VIEW
    ////////////////////////////////////////////////////////////////
    if (startJustPressed) {
      defenderState = MAP_VIEW;
    } 

    ////////////////////////////////////////////////////////////////
    // GOES TO TOOL SELECT MODE
    ////////////////////////////////////////////////////////////////
    if (selectJustPressed) {
      defenderState = TOOL_SELECT;
    }

  }

}

//////////////////////////////////////////////////////
// Resets the game
//////////////////////////////////////////////////////
void resetGame() {
    hackerPosition = -1;
    tracePositions[0] = -1;
    tracePositions[1] = -1;
    activeTraces = 0;
    selectedNode = -1;
    speedBoostUsage = 2;
    speedBoostDuration = 0;
    nodeLockUsage = 3;
    pingScanUsage = 3;
    currentTurn = DEFENDER_TURN;
    currentStatus = HACKER_SELECT;
    gameOverNotified = false;
    result = NONE_RESULT;

    activeTool = TOOL_NODELOCK;
    toolIndex = 0;
    toolConfirmed = false;
    pingScanActive = false;
    pingScanCooldown = false;
    pingScanRevealTurns = 0;
    speedBoostActive = false;
    speedBoostMoveOne = false;

    hackerSpoofActive = false;
    spoofedHackerPosition = -1;

    // Reset all node occupants and locks
    for (int i = 0; i < 24; i++) {
        nodes[i].occupant = NONE;
        nodes[i].traceCount = 0;
        nodes[i].isLocked = false;
    }
}