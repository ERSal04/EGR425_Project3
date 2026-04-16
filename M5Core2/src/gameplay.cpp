#include "gameplay.h"
#include "ble_server.h"
#include <Adafruit_seesaw.h>

extern Adafruit_seesaw gamepad;

#define BUTTON_X      6
#define BUTTON_Y      2
#define BUTTON_A      5
#define BUTTON_B      1
#define BUTTON_START  16
#define BUTTON_SELECT 0

void handleWaitingToConnect() {
    if (testMode) currentStatus = HACKER_SELECT;
}

void handleHackerSelect() {
    if (testMode && hackerPosition == -1) {
        hackerPosition = testPath[0];
        testPathIndex  = 1;
        initializeTraces();
        nodes[hackerPosition].occupant = HACKER;
        currentStatus = GAME_IN_PROGRESS;
        return;
    }
    if (hackerPosition != -1) {
        Serial.printf("[SERVER] Hacker selected entry node: %d\n", hackerPosition);
        initializeTraces();
        nodes[hackerPosition].occupant = HACKER;
        currentStatus = GAME_IN_PROGRESS;
    }
}

void handleGameplay() {
    switch (currentTurn) {
        case HACKER_TURN:   handleHackerTurn();   break;
        case DEFENDER_TURN: handleDefenderTurn(); break;
    }
}

void handleGameOver() {
    if (!gameOverNotified) {
        sendDefenderState();
        gameOverNotified = true;

        // POST result to GCP then fetch leaderboard
        const char* winner = (result == HACKER_WIN) ? "hacker" : "defender";
        postWinToGCP(winner);
        fetchLeaderboard();

        // Transition to leaderboard after short delay
        delay(2500); // show game over screen briefly first
        currentStatus = LEADERBOARD;
    }
}

void handleHackerTurn() {
    if (!testMode) return;

    unsigned long now = millis();
    if (now - lastTestMoveMs < testMoveInterval) return;
    lastTestMoveMs = now;

    if (testPathIndex < 7) {
        int oldPos     = hackerPosition;
        hackerPosition = testPath[testPathIndex++];

        if (oldPos >= 0) nodes[oldPos].occupant = NONE;
        nodes[hackerPosition].occupant = HACKER;

        Serial.printf("[TEST] Hacker auto-moved to node: %d\n", hackerPosition);

        if (nodes[hackerPosition].type == CORE) {
            result = HACKER_WIN; currentStatus = GAME_OVER;
        }
        if (tracePositions[0] == hackerPosition || tracePositions[1] == hackerPosition) {
            result = DEFENDER_WIN; currentStatus = GAME_OVER;
        }

        currentTurn = DEFENDER_TURN;

        if (pingScanActive) {
            pingScanRevealTurns--;
            if (pingScanRevealTurns <= 0) {
                pingScanActive   = false;
                pingScanCooldown = false;
            }
        }
    }
}

void handleDefenderTurn() {
    extern uint32_t button_mask;

    int joyX = 1023 - gamepad.analogRead(14);
    int joyY = gamepad.analogRead(15);

    int dx = joyX - 512;
    int dy = joyY - 512;
    const int deadzone = 45;
    if (abs(dx) < deadzone) dx = 0;
    if (abs(dy) < deadzone) dy = 0;

    uint32_t buttons = gamepad.digitalReadBulk(0xFFFFFFFF);

    bool pushingLeft  = joyX < 412;
    bool pushingRight = joyX > 612;

    bool startPressed  = !(buttons & (1UL << BUTTON_START));
    bool selectPressed = !(buttons & (1UL << BUTTON_SELECT));
    bool bPressed      = !(buttons & (1UL << BUTTON_B));
    bool yPressed      = !(buttons & (1UL << BUTTON_Y));

    static bool lastStart = false, lastSelect = false, lastB = false, lastY = false;
    static bool lastPushLeft = false, lastPushRight = false;
    static unsigned long lastDebounceTime = 0;
    const unsigned long debounceDelay = 200;

    bool startJustPressed  = startPressed  && !lastStart;
    bool selectJustPressed = selectPressed && !lastSelect;
    bool bJustPressed      = bPressed      && !lastB;
    bool yJustPressed      = yPressed      && !lastY;
    bool leftJustPushed    = pushingLeft   && !lastPushLeft;
    bool rightJustPushed   = pushingRight  && !lastPushRight;

    if (startJustPressed || selectJustPressed || bJustPressed ||
        yJustPressed || leftJustPushed || rightJustPushed) {
        unsigned long now = millis();
        if (now - lastDebounceTime < debounceDelay) {
            startJustPressed = selectJustPressed = bJustPressed =
            yJustPressed = leftJustPushed = rightJustPushed = false;
        } else {
            lastDebounceTime = now;
        }
    }

    lastStart      = startPressed;
    lastSelect     = selectPressed;
    lastB          = bPressed;
    lastY          = yPressed;
    lastPushLeft   = pushingLeft;
    lastPushRight  = pushingRight;

    // ── MAP VIEW ─────────────────────────────────────────────
    if (defenderState == MAP_VIEW) {
        cameraX += dx * 0.1f;
        cameraY += dy * 0.1f;
        cameraX = constrain(cameraX, 0, 580);
        cameraY = constrain(cameraY, 0, 660);

        if (startJustPressed) {
            if (tracePositions[0] == -1 && tracePositions[1] == -1) initializeTraces();
            connectionIndex = -1;
            defenderState   = NODE_SELECT;
        }
        if (selectJustPressed) defenderState = TOOL_SELECT;

    // ── TOOL SELECT ──────────────────────────────────────────
    } else if (defenderState == TOOL_SELECT) {

        if (!toolConfirmed) {
            if (rightJustPushed) { toolIndex = (toolIndex + 1) % 3; activeTool = (DefenderTool)toolIndex; }
            if (leftJustPushed)  { toolIndex = (toolIndex + 2) % 3; activeTool = (DefenderTool)toolIndex; }

            if (startJustPressed) {
                if (activeTool == TOOL_NODELOCK && nodeLockUsage > 0) {
                    toolConfirmed   = true;
                    connectionIndex = 0;
                    selectedNode    = 0;

                } else if (activeTool == TOOL_SPEEDBOOST && speedBoostUsage > 0) {
                    speedBoostActive = true;
                    speedBoostUsage--;
                    sendDefenderState();
                    currentTurn   = HACKER_TURN;
                    defenderState = MAP_VIEW;

                } else if (activeTool == TOOL_PINGSCAN && pingScanUsage > 0 && !pingScanCooldown) {
                    pingScanActive      = true;
                    pingScanUsage--;
                    pingScanCooldown    = true;
                    pingScanRevealTurns = 1;

                    if (hackerSpoofActive) {
                        cameraX = nodes[spoofedHackerPosition].worldX - 160;
                        cameraY = nodes[spoofedHackerPosition].worldY - 120;
                        hackerSpoofActive = false;
                    } else {
                        spoofedHackerPosition = -1;
                        cameraX = nodes[hackerPosition].worldX - 160;
                        cameraY = nodes[hackerPosition].worldY - 120;
                    }
                    sendDefenderState();
                    currentTurn   = HACKER_TURN;
                    defenderState = MAP_VIEW;
                }
            }
        } else {
            // Node lock — cycle all 24 nodes
            if (rightJustPushed) {
                connectionIndex = (connectionIndex + 1) % 24;
                selectedNode    = connectionIndex;
                cameraX = nodes[selectedNode].worldX - 160;
                cameraY = nodes[selectedNode].worldY - 120;
            }
            if (leftJustPushed) {
                connectionIndex = (connectionIndex + 23) % 24;
                selectedNode    = connectionIndex;
                cameraX = nodes[selectedNode].worldX - 160;
                cameraY = nodes[selectedNode].worldY - 120;
            }
            if (bJustPressed && !nodes[selectedNode].isLocked) {
                nodes[selectedNode].isLocked = true;
                nodeLockUsage--;
                toolConfirmed = false;
                sendDefenderState();
                currentTurn   = HACKER_TURN;
                defenderState = MAP_VIEW;
            }
            if (selectJustPressed) toolConfirmed = false;
        }

        if (selectJustPressed && !toolConfirmed) defenderState = MAP_VIEW;

    // ── NODE SELECT ──────────────────────────────────────────
    } else {

        if (selectedNode == -1 && connectionIndex != -1) {
            cameraX = nodes[tracePositions[selectedTrace]].worldX - 160;
            cameraY = nodes[tracePositions[selectedTrace]].worldY - 120;
        } else if (selectedNode != -1) {
            cameraX = nodes[selectedNode].worldX - 160;
            cameraY = nodes[selectedNode].worldY - 120;
        }

        if (yJustPressed) {
            connectionIndex = -1;
            selectedTrace   = (selectedTrace == 1) ? 0 : selectedTrace + 1;
            cameraX = nodes[tracePositions[selectedTrace]].worldX - 160;
            cameraY = nodes[tracePositions[selectedTrace]].worldY - 120;
        }

        if (rightJustPushed) {
            connectionIndex = (connectionIndex != nodes[tracePositions[selectedTrace]].connectionCount - 1)
                ? connectionIndex + 1 : -1;
        }
        if (leftJustPushed) {
            connectionIndex = (connectionIndex != -1)
                ? connectionIndex - 1
                : nodes[tracePositions[selectedTrace]].connectionCount - 1;
        }

        selectedNode = (connectionIndex == -1)
            ? tracePositions[selectedTrace]
            : nodes[tracePositions[selectedTrace]].connections[connectionIndex];

        if (bJustPressed) {
            if (connectionIndex == -1) {
                // no neighbor selected yet
            } else if (nodes[selectedNode].isLocked) {
                // locked — do nothing
            } else {
                nodes[tracePositions[selectedTrace]].traceCount--;
                nodes[tracePositions[selectedTrace]].occupant = NONE;
                tracePositions[selectedTrace] = selectedNode;

                if (tracePositions[selectedTrace] == hackerPosition) {
                    result        = DEFENDER_WIN;
                    currentStatus = GAME_OVER;
                    sendDefenderState();
                    currentTurn      = HACKER_TURN;
                    defenderState    = MAP_VIEW;
                    speedBoostMoveOne = false;
                    speedBoostActive  = false;
                } else {
                    nodes[tracePositions[selectedTrace]].traceCount++;
                    nodes[tracePositions[selectedTrace]].occupant = TRACE;

                    if (speedBoostActive && !speedBoostMoveOne) {
                        speedBoostMoveOne = true;
                        connectionIndex   = -1;
                    } else {
                        sendDefenderState();
                        currentTurn       = HACKER_TURN;
                        defenderState     = MAP_VIEW;
                        speedBoostMoveOne = false;
                        speedBoostActive  = false;
                    }
                }
            }
        }

        if (startJustPressed)  defenderState = MAP_VIEW;
        if (selectJustPressed) defenderState = TOOL_SELECT;
    }
}
