#include "map_data.h"

void initializeMap1() {
    int c0[]  = {4, 6};
    int c1[]  = {5, 8};
    int c2[]  = {6, 11};
    int c3[]  = {8, 12};
    int c4[]  = {0, 6, 7};
    int c5[]  = {1, 7, 8};
    int c6[]  = {0, 2, 4, 9, 11};
    int c7[]  = {4, 5, 9, 10};
    int c8[]  = {1, 3, 5, 10, 12};
    int c9[]  = {6, 7, 13, 15};
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

    nodes[0]  = makeNode(0,  80,  800, ENTRY,    c0,  2);
    nodes[1]  = makeNode(1,  820, 800, ENTRY,    c1,  2);
    nodes[2]  = makeNode(2,  80,  100, ENTRY,    c2,  2);
    nodes[3]  = makeNode(3,  820, 100, ENTRY,    c3,  2);
    nodes[4]  = makeNode(4,  200, 700, NORMAL,   c4,  3);
    nodes[5]  = makeNode(5,  700, 700, NORMAL,   c5,  3);
    nodes[6]  = makeNode(6,  150, 550, NORMAL,   c6,  5);
    nodes[7]  = makeNode(7,  450, 650, NORMAL,   c7,  4);
    nodes[8]  = makeNode(8,  750, 550, NORMAL,   c8,  5);
    nodes[9]  = makeNode(9,  300, 480, NORMAL,   c9,  4);
    nodes[10] = makeNode(10, 600, 480, NORMAL,   c10, 4);
    nodes[11] = makeNode(11, 100, 380, NORMAL,   c11, 4);
    nodes[12] = makeNode(12, 800, 380, NORMAL,   c12, 4);
    nodes[13] = makeNode(13, 250, 300, NORMAL,   c13, 4);
    nodes[14] = makeNode(14, 650, 300, NORMAL,   c14, 4);
    nodes[15] = makeNode(15, 450, 350, JUNCTION, c15, 5);
    nodes[16] = makeNode(16, 150, 200, NORMAL,   c16, 3);
    nodes[17] = makeNode(17, 750, 200, NORMAL,   c17, 3);
    nodes[18] = makeNode(18, 350, 220, NORMAL,   c18, 3);
    nodes[19] = makeNode(19, 550, 220, NORMAL,   c19, 3);
    nodes[20] = makeNode(20, 250, 120, NORMAL,   c20, 3);
    nodes[21] = makeNode(21, 650, 120, NORMAL,   c21, 3);
    nodes[22] = makeNode(22, 450, 160, NORMAL,   c22, 5);
    nodes[23] = makeNode(23, 450, 450, CORE,     c23, 4);

    // Map 1 camera starts centered on JUNCTION
    cameraX = 290;
    cameraY = 130;
}

void initializeMap2() {
    int c0[]  = {5, 16};                     // ENTRY_A
    int c1[]  = {8, 19};                     // ENTRY_B
    int c2[]  = {10, 4};                     // ENTRY_C
    int c3[]  = {15, 7};                     // ENTRY_D
    int c4[]  = {22, 11, 17, 2};             // NODE_04
    int c5[]  = {9, 6, 0};                   // NODE_05
    int c6[]  = {9, 5, 16, 18, 11};          // NODE_06
    int c7[]  = {23, 14, 20, 3};             // NODE_07
    int c8[]  = {9, 13, 1};                  // NODE_08
    int c9[]  = {5, 8, 13, 6};               // NODE_09
    int c10[] = {2, 12, 11};                 // NODE_10
    int c11[] = {10, 12, 17, 4, 6};          // NODE_11
    int c12[] = {10, 15, 11, 14};            // NODE_12
    int c13[] = {9, 8, 19, 21, 14};          // NODE_13
    int c14[] = {12, 20, 7, 13, 15};         // NODE_14
    int c15[] = {3, 12, 14};                 // NODE_15
    int c16[] = {22, 6, 18, 0};              // NODE_16
    int c17[] = {22, 4, 11};                 // NODE_17
    int c18[] = {22, 16, 6};                 // NODE_18
    int c19[] = {23, 13, 21, 1};             // NODE_19
    int c20[] = {23, 7, 14};                 // NODE_20
    int c21[] = {23, 19, 13};                // NODE_21
    int c22[] = {4, 17, 18, 16, 24};         // JUNCTION_L
    int c23[] = {7, 20, 21, 19, 24};         // JUNCTION_R
    int c24[] = {22, 23};                    // CORE

    nodes[0]  = makeNode(0,  80,  800, ENTRY,    c0,  2);
    nodes[1]  = makeNode(1,  820, 800, ENTRY,    c1,  2);
    nodes[2]  = makeNode(2,  80,  100, ENTRY,    c2,  2);
    nodes[3]  = makeNode(3,  820, 100, ENTRY,    c3,  2);
    nodes[4]  = makeNode(4,  173, 315, NORMAL,   c4,  4);
    nodes[5]  = makeNode(5,  266, 738, NORMAL,   c5,  3);
    nodes[6]  = makeNode(6,  357, 558, NORMAL,   c6,  5);
    nodes[7]  = makeNode(7,  727, 315, NORMAL,   c7,  4);
    nodes[8]  = makeNode(8,  635, 738, NORMAL,   c8,  3);
    nodes[9]  = makeNode(9,  450, 657, NORMAL,   c9,  4);
    nodes[10] = makeNode(10, 266, 162, NORMAL,   c10, 3);
    nodes[11] = makeNode(11, 357, 342, NORMAL,   c11, 5);
    nodes[12] = makeNode(12, 450, 243, NORMAL,   c12, 4);
    nodes[13] = makeNode(13, 543, 558, NORMAL,   c13, 5);
    nodes[14] = makeNode(14, 543, 342, NORMAL,   c14, 5);
    nodes[15] = makeNode(15, 635, 162, NORMAL,   c15, 3);
    nodes[16] = makeNode(16, 173, 585, NORMAL,   c16, 4);
    nodes[17] = makeNode(17, 266, 396, NORMAL,   c17, 3);
    nodes[18] = makeNode(18, 266, 504, NORMAL,   c18, 3);
    nodes[19] = makeNode(19, 727, 585, NORMAL,   c19, 4);
    nodes[20] = makeNode(20, 635, 396, NORMAL,   c20, 3);
    nodes[21] = makeNode(21, 635, 504, NORMAL,   c21, 3);
    nodes[22] = makeNode(22, 90,  450, JUNCTION, c22, 5);
    nodes[23] = makeNode(23, 810, 450, JUNCTION, c23, 5);
    nodes[24] = makeNode(24, 450, 450, CORE,     c24, 2);

    cameraX = 290;
    cameraY = 210;
}

void initializeSelectedMap() {
    if (selectedMap == 0) initializeMap1();
    else                  initializeMap2();
}
