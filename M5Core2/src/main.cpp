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

int hackerPosition = -1; // Hackers current position
int tracePositions[2] = {-1, -1}; // Array containing the positions of the tracers
int selectedTrace = 0; // which trace (0 or 1) is being moved
int connectionIndex = -1; // Index that helps cycle through neighboring nodes
int activeTraces = 0; // Count of how many active traces
int selectedNode = -1; // Selected Node to make an action on
int speedBoostUsage = 2; // Count of how many speed boosts left
int speedBoostDuration = 0; // Count of how long the speed boost is active for
int nodeLockUsage = 3; // Count of how many nodes can be locked
int pingScanUsage = 3; // Number of ping scans left

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

        // Indicate if the node contains a trace
        if(currentNode.traceCount > 0) {
          sprite.fillCircle(screenX, screenY, nodeRadius - 2, TFT_PURPLE);
        }

        // If selected Node contains a trace, expand the Purple
        if (i == selectedNode && currentNode.traceCount > 0) {
          sprite.fillCircle(screenX, screenY, nodeRadius, TFT_PURPLE);
        } else if (i == selectedNode) {
          // If node is selected, highlight it
          sprite.drawCircle(screenX, screenY, nodeRadius + 4, TFT_WHITE);
        }

        if(defenderState == NODE_SELECT) {
          sprite.fillRect(0, 210, 320, 30, TFT_DARKGREY);
          sprite.setTextColor(TFT_WHITE);
          sprite.setCursor(5, 218);
          sprite.printf("T%d < Node %d > B:Move", 
              selectedTrace, selectedNode);
        }
      }
    }
  }

  // Push constructed frame
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

    ////////////////////////////////////////////////////////////////
    // GOES TO NODE SELECT MODE
    ////////////////////////////////////////////////////////////////
    if (startJustPressed) {
      defenderState = NODE_SELECT;
    } 

    ////////////////////////////////////////////////////////////////
    // RETURNS TO MAP VIEW FROM TOOL SELECT
    ////////////////////////////////////////////////////////////////
    if (selectJustPressed) {
      defenderState = MAP_VIEW;
    }

  ////////////////////////////////////////////////////////////////
  // NODE SELECT MODE
  //////////////////////////////////////////////////////////////// 
  } else {

    // NEED TO DRAW AN INDICATOR WHERE THE TRACE NODES AREEEE
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

        // Decrease the count of traces on selectedTrace's node before updating the selectedTrace's position 
        nodes[tracePositions[selectedTrace]].traceCount--;
        nodes[tracePositions[selectedTrace]].occupant = NONE;

        // Update selectedTrace's position to new node
        tracePositions[selectedTrace] = selectedNode;

        // Check if the trace landed on hacker position
        if (tracePositions[selectedTrace] == hackerPosition) {
          currentStatus = GAME_OVER;
          handleGameOver();
        } else {
          // Increment new selectedTrace's current node's trace count
          nodes[tracePositions[selectedTrace]].traceCount++;
          nodes[tracePositions[selectedTrace]].occupant = TRACE;
        }

        // End turn for defender
        currentTurn = HACKER_TURN;

        // Return to MAP_VIEW for defender
        defenderState = MAP_VIEW;
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

    // Reset all node occupants and locks
    for (int i = 0; i < 24; i++) {
        nodes[i].occupant = NONE;
        nodes[i].traceCount = 0;
        nodes[i].isLocked = false;
    }
}