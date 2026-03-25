#include <Arduino.h>
#include <M5Core2.h>
#include <Adafruit_seesaw.h>

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
#define BUTTON_SELECT 14

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
void handleHackerSelect();
void handleGameplay();
void handleGameOver();
void resetGame(); 

// Handles switching between player turns
void handleHackerTurn();
void handleDefenderTurn();

//////////////////////////////////////////////////////
// Variable Declarations
//////////////////////////////////////////////////////
Node nodes[24];

int hackerPosition = -1;
int tracePosition[2] = {-1, -1};
int selectedTrace = 0; // which trace (0 or 1) is being moved
int activeTraces = 0;
int selectedNode = 23;
int speedBoostUsage = 2;
int speedBoostDuration = 0;
int nodeLockUsage = 3;
int pingScanUsage = 3;

enum gameStatus { HACKER_SELECT, GAME_IN_PROGRESS, GAME_OVER };
gameStatus currentStatus = HACKER_SELECT;
enum playerTurn { HACKER_TURN, DEFENDER_TURN };
playerTurn currentTurn = DEFENDER_TURN;

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

void drawScreen() {

  sprite.fillScreen(TFT_BLACK);

  if (currentStatus == GAME_OVER) {
    sprite.fillScreen(TFT_BLACK);
    sprite.print("GAME OVER");

    if (M5.BtnA.wasPressed()) {
      currentStatus = HACKER_SELECT;
    }
  } else if(currentStatus == HACKER_SELECT) {
    sprite.print("Waiting for Hacker...");
  } else {

    // Loop through each node
    for (int i = 0; i < 24; i++) {

      // Get the current Node and its relative position to the camera
      Node currentNode = nodes[i];
      int screenX = (int) currentNode.worldX - cameraX;
      int screenY = (int) currentNode.worldY - cameraY;

      // Check if each node is in the camera view
      if (screenX >= 0 && screenX <= 320 && screenY >= 0 && screenY <= 240) {
        
        // Loop through the Node connections and draw a line between the coords of each connected node
        for (int j = 0; j < currentNode.connectionCount; j++) {
          int connectingNodeId = nodes[i].connections[j];

          int x1 = (int)(nodes[i].worldX - cameraX);
          int y1 = (int)(nodes[i].worldY - cameraY);
          int x2 = (int)(nodes[connectingNodeId].worldX - cameraX);
          int y2 = (int)(nodes[connectingNodeId].worldY - cameraY);
          sprite.drawLine(x1, y1, x2, y2, TFT_DARKGREY);
        }

        // Get the color and radius of current node
        uint32_t nodeColor = getNodeColor(currentNode.type);
        nodeRadius = getNodeRadius(currentNode.type);

        // Draw the Node
        sprite.fillCircle(screenX, screenY, nodeRadius, nodeColor);

        // If node is selected, highlight it
        if (i == selectedNode) {
          sprite.drawCircle(screenX, screenY, nodeRadius + 4, TFT_WHITE);
        }
      }
    }
  }

  // Push constructed frame
  sprite.pushSprite(0, 0);
}

void initializeTraces() {
  int randomNode = random(9, 23);

  tracePosition[0] = randomNode;
  randomNode = random(9, 23);

  while (tracePosition[1] == -1) {
    if (randomNode == tracePosition[0]) {
      randomNode = random(9, 23);
    } else {
      tracePosition[1] = randomNode;
    }
  }

}

void setup() {
  
  M5.begin();

  if (!gamepad.begin(0x50)) {
    Serial.print("Seesaw not found");
    while(1);
  }

  // Sprite frame Generator
  sprite.createSprite(320, 240);

  // Random seed generator
  randomSeed(analogRead(0));

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
}

void loop() {
  switch(currentStatus) {
    case HACKER_SELECT:       handleHackerSelect(); break;
    case GAME_IN_PROGRESS:    handleGameplay(); break;
    case GAME_OVER:           handleGameOver(); break;
  }
  drawScreen();

}


//////////////////////////////////////////////////////
// Functions that handle the different states of the game
//////////////////////////////////////////////////////
void handleHackerSelect() {
  if (hackerPosition == -1) {
      hackerPosition = 0;
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

}


//////////////////////////////////////////////////////
// Functions that run depending on whose turn it is
//////////////////////////////////////////////////////

void handleHackerTurn() {

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

  if(defenderState == MAP_VIEW) {
    float speed = 0.1f;
    // Trying to invert the controls and fix map
    cameraX += dx * speed;
    cameraY += dy * speed;
    
    // Prevents the user from scrolling off the map
    cameraX = constrain(cameraX, 0, 580);
    cameraY = constrain(cameraY, 0, 660);

    static bool lastStart = false;
    static bool lastSelect = false;
    // Goes to NODE_SELECT mode
    if (startPressed && !lastStart) {
      defenderState = NODE_SELECT;
      Serial.printf("Switching mode to: %d/n", defenderState);
    } 
    lastStart = startPressed;

    // Goes to TOOL_SELECT mode
    if (selectPressed && !lastSelect) {
      defenderState = TOOL_SELECT;
      Serial.printf("Switching mode to: %d/n", defenderState);
    }
    lastSelect = selectPressed;


  } else if (defenderState == TOOL_SELECT) {

    // Goes to NODE_SELECT mode
    if (startPressed) {
      defenderState = NODE_SELECT;
    } 

    // Returns to MAP_VIEW mode
    if (selectPressed) {
      defenderState = MAP_VIEW;
    }

    return;
  } else {
    // Reset camera position to center on the selectedNode 
    cameraX = nodes[selectedNode].worldX - 160;
    cameraY = nodes[selectedNode].worldY - 120;
    Serial.print("Reseting Position");

    // Returns back to MAP_VIEW mode
    if (startPressed) {
      defenderState = MAP_VIEW;
    } 

    // Goes to TOOL_SELECT mode
    if (selectPressed) {
      defenderState = TOOL_SELECT;
    }

    return;
  }
  
}

//////////////////////////////////////////////////////
// Resets the game
//////////////////////////////////////////////////////
void resetGame() {
    hackerPosition = -1;
    tracePosition[0] = -1;
    tracePosition[1] = -1;
    activeTraces = 0;
    selectedNode = -1;
    speedBoostUsage = 2;
    speedBoostDuration = 0;
    nodeLockUsage = 3;
    pingScanUsage = 3;
    currentTurn = DEFENDER_TURN;
    currentStatus = HACKER_SELECT;

    // Reset all node occupants and locks
    for (int i = 0; i < 24; i++) {
        nodes[i].occupant = NONE;
        nodes[i].traceCount = 0;
        nodes[i].isLocked = false;
    }
}