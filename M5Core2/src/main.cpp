#include <Arduino.h>
#include <M5Core2.h>

//////////////////////////////////////////////////////
// Decleration of Enums
//////////////////////////////////////////////////////
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

//////////////////////////////////////////////////////
// Variable Declarations
//////////////////////////////////////////////////////
Node nodes[24];
float cameraX = 290;
float cameraY = 130;

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

void setup() {
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
  // put your main code here, to run repeatedly:
}