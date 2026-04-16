#include "renderer.h"
#include "wifi_gcp.h"

TFT_eSprite sprite = TFT_eSprite(&M5.Lcd);

uint32_t getNodeColor(NodeType type) {
    switch (type) {
        case ENTRY:    return TFT_YELLOW;
        case NORMAL:   return TFT_GREEN;
        case JUNCTION: return TFT_CYAN;
        case CORE:     return TFT_RED;
        default:       return TFT_GREEN;
    }
}

int getNodeRadius(NodeType type) {
    switch (type) {
        case ENTRY:    return 6;
        case NORMAL:   return 4;
        case JUNCTION: return 8;
        case CORE:     return 10;
        default:       return 4;
    }
}

void drawScreen() {
    sprite.fillScreen(TFT_BLACK);

    // ── WAITING TO CONNECT ──────────────────────────────────
    if (currentStatus == WAITING_TO_CONNECT) {
        sprite.setTextSize(2);
        for (int i = 0; i < 10; i++) {
            sprite.setCursor(random(0, 320), random(0, 240));
            sprite.print(random(0, 2));
        }
        for (int i = 0; i < 15; i++) {
            sprite.setTextColor(TFT_DARKGREEN);
            sprite.setCursor(random(0, 320), random(0, 240));
            sprite.print(random(0, 2));
        }
        sprite.setTextColor(TFT_GREEN, TFT_BLACK);
        sprite.setCursor(40, 80);  sprite.print("INITIALIZING...");
        sprite.setCursor(20, 110); sprite.print("AWAITING CONNECTION");

        int dots = (millis() / 500) % 4;
        sprite.setCursor(260, 110);
        for (int i = 0; i < dots; i++) sprite.print(".");

        sprite.drawRect(10, 180, 300, 20, TFT_GREEN);
        sprite.fillRect(10, 180, (millis() / 50) % 300, 20, TFT_GREEN);

    // ── GAME OVER ───────────────────────────────────────────
    } else if (currentStatus == GAME_OVER) {
        bool blink = (millis() / 400) % 2;
        sprite.setTextSize(2);

        if (result == HACKER_WIN) {
            sprite.setTextColor(blink ? TFT_RED : TFT_DARKGREY);
            sprite.setCursor(40, 60);  sprite.print("CORE BREACHED");
            sprite.setTextColor(TFT_RED);
            sprite.setCursor(30, 100); sprite.print("SYSTEM FAILURE");
            sprite.setTextSize(1);
            sprite.setCursor(20, 140); sprite.print("> ROOT ACCESS GRANTED");
        } else if (result == DEFENDER_WIN) {
            sprite.setTextColor(blink ? TFT_GREEN : TFT_DARKGREEN);
            sprite.setCursor(40, 60);  sprite.print("TRACE COMPLETE");
            sprite.setTextColor(TFT_GREEN);
            sprite.setCursor(20, 100); sprite.print("INTRUDER ELIMINATED");
            sprite.setTextSize(1);
            sprite.setCursor(20, 140); sprite.print("> SYSTEM SECURED");
        }

        sprite.setTextSize(1);
        sprite.setTextColor(TFT_WHITE);
        sprite.setCursor(40, 200); sprite.print("Press A to reboot");
        if (M5.BtnA.wasPressed()) resetGame();

    // ── HACKER SELECT ───────────────────────────────────────
    } else if (currentStatus == MAP_SELECT) {
        sprite.fillScreen(TFT_BLACK);

        sprite.setTextColor(TFT_CYAN);
        sprite.setTextSize(2);
        sprite.setCursor(60, 30);
        sprite.print("SELECT MAP");
        sprite.drawFastHLine(0, 55, 320, TFT_CYAN);

        // Map 1 box
        uint32_t m1color = (selectedMap == 0) ? TFT_YELLOW : TFT_DARKGREY;
        sprite.drawRect(20, 70, 130, 80, m1color);
        sprite.setTextColor(m1color);
        sprite.setTextSize(1);
        sprite.setCursor(35, 90);
        sprite.print("MAP 1");
        sprite.setCursor(28, 105);
        sprite.print("GRID NETWORK");
        sprite.setCursor(28, 120);
        sprite.print("24 nodes");
        sprite.setCursor(28, 135);
        sprite.print("1 Junction");

        // Map 2 box
        uint32_t m2color = (selectedMap == 1) ? TFT_YELLOW : TFT_DARKGREY;
        sprite.drawRect(170, 70, 130, 80, m2color);
        sprite.setTextColor(m2color);
        sprite.setCursor(185, 90);
        sprite.print("MAP 2");
        sprite.setCursor(178, 105);
        sprite.print("STAR NETWORK");
        sprite.setCursor(178, 120);
        sprite.print("22 nodes");
        sprite.setCursor(178, 135);
        sprite.print("2 Junctions");

        // Arrow indicators
        sprite.setTextColor(TFT_WHITE);
        sprite.setTextSize(2);
        sprite.setCursor(148, 100);
        sprite.print((selectedMap == 0) ? ">" : "<");

        // Confirm hint
        sprite.setTextSize(1);
        sprite.setTextColor(TFT_GREEN);
        sprite.setCursor(60, 185);
        sprite.print("< > to cycle   START to confirm");
    } else if (currentStatus == HACKER_SELECT) {
        sprite.setTextColor(TFT_GREEN, TFT_BLACK);
        sprite.setTextSize(2);
        sprite.setCursor(20, 100);
        sprite.print("Waiting for Hacker...");
    
    } else if (currentStatus == LEADERBOARD) {
        sprite.fillScreen(TFT_BLACK);

        // Title
        sprite.setTextColor(TFT_CYAN);
        sprite.setTextSize(2);
        sprite.setCursor(60, 15);
        sprite.print("LEADERBOARD");
        sprite.drawFastHLine(0, 35, 320, TFT_CYAN);

        if (!gcpDataReady) {
            // Still loading
            sprite.setTextColor(TFT_WHITE);
            sprite.setTextSize(1);
            sprite.setCursor(90, 110);
            sprite.print("Fetching data");
            int dots = (millis() / 400) % 4;
            for (int i = 0; i < dots; i++) sprite.print(".");
        } else {
            // Hacker wins row
            sprite.setTextSize(2);
            sprite.setTextColor(TFT_RED);
            sprite.setCursor(20, 60);
            sprite.print("HACKER");
            sprite.setTextColor(TFT_WHITE);
            sprite.setCursor(200, 60);
            sprite.printf("%d wins", gcpHackerWins);

            // Divider
            sprite.drawFastHLine(20, 95, 280, TFT_DARKGREY);

            // Defender wins row
            sprite.setTextColor(TFT_GREEN);
            sprite.setCursor(20, 105);
            sprite.print("DEFENDER");
            sprite.setTextColor(TFT_WHITE);
            sprite.setCursor(200, 105);
            sprite.printf("%d wins", gcpDefenderWins);

            // Who's winning overall
            sprite.setTextSize(1);
            sprite.drawFastHLine(0, 145, 320, TFT_DARKGREY);
            sprite.setCursor(20, 155);
            if (gcpHackerWins > gcpDefenderWins) {
                sprite.setTextColor(TFT_RED);
                sprite.print("Hackers are dominating the network");
            } else if (gcpDefenderWins > gcpHackerWins) {
                sprite.setTextColor(TFT_GREEN);
                sprite.print("Defenders are securing the system");
            } else {
                sprite.setTextColor(TFT_YELLOW);
                sprite.print("The network is contested");
            }

            // Reset prompt
            sprite.setTextColor(TFT_WHITE);
            sprite.setCursor(80, 210);
            sprite.print("Press A to play again");
        }

    // ── GAME IN PROGRESS ────────────────────────────────────
    } else {

        // PASS 1 — edges (no viewport check — sprite clips automatically)
        for (int i = 0; i < mapNodeCount; i++) {
            for (int j = 0; j < nodes[i].connectionCount; j++) {
                int nb = nodes[i].connections[j];
                if (nb > i) {
                    int x1 = (int)(nodes[i].worldX - cameraX);
                    int y1 = (int)(nodes[i].worldY - cameraY);
                    int x2 = (int)(nodes[nb].worldX  - cameraX);
                    int y2 = (int)(nodes[nb].worldY  - cameraY);
                    sprite.drawLine(x1, y1, x2, y2, TFT_DARKGREY);
                }
            }
        }

        // PASS 2 — nodes (viewport check respects status bar)
        for (int i = 0; i < mapNodeCount; i++) {
            Node& cur = nodes[i];
            int screenX = (int)(cur.worldX - cameraX);
            int screenY = (int)(cur.worldY - cameraY);

            if (screenX < 0 || screenX > 320 || screenY < 18 || screenY > 210) continue;

            nodeRadius = getNodeRadius(cur.type);
            sprite.fillCircle(screenX, screenY, nodeRadius, getNodeColor(cur.type));

            // Lock indicator
            if (cur.isLocked) {
                sprite.fillRect(screenX - 7, screenY - nodeRadius - 10, 14, 10, TFT_ORANGE);
                sprite.drawLine(screenX - 4, screenY - nodeRadius - 10,
                                screenX - 4, screenY - nodeRadius - 16, TFT_ORANGE);
                sprite.drawLine(screenX + 4, screenY - nodeRadius - 10,
                                screenX + 4, screenY - nodeRadius - 16, TFT_ORANGE);
                sprite.drawLine(screenX - 4, screenY - nodeRadius - 16,
                                screenX + 4, screenY - nodeRadius - 16, TFT_ORANGE);
                // Keyhole dot in center of body
                sprite.fillCircle(screenX, screenY - nodeRadius - 7, 2, TFT_BLACK);
                // Orange outline on node
                sprite.drawCircle(screenX, screenY, nodeRadius + 3, TFT_ORANGE);
            }

            // Hacker dot (test mode)
            if (i == hackerPosition && testMode)
                sprite.fillCircle(screenX, screenY, nodeRadius - 2, TFT_PINK);

            // Trace dot
            if (cur.traceCount > 0)
                sprite.fillCircle(screenX, screenY, nodeRadius - 2, TFT_PURPLE);

            // Selection highlight
            if (i == selectedNode && cur.traceCount > 0)
                sprite.fillCircle(screenX, screenY, nodeRadius, TFT_PURPLE);
            else if (i == selectedNode)
                sprite.drawCircle(screenX, screenY, nodeRadius + 4, TFT_WHITE);
        }

        // TOP STATUS BAR
        sprite.fillRect(0, 0, 320, 18, 0x1082);
        sprite.drawFastHLine(0, 18, 320, TFT_CYAN);
        sprite.setTextSize(1);

        if (currentTurn == DEFENDER_TURN) {
            sprite.setTextColor(TFT_GREEN);
            sprite.setCursor(4, 5); sprite.print("DEFENDER TURN");
        } else {
            sprite.setTextColor(TFT_RED);
            sprite.setCursor(4, 5); sprite.print("HACKER TURN");
        }

        sprite.setTextColor(TFT_CYAN);
        sprite.setCursor(110, 5);
        if      (defenderState == MAP_VIEW)    sprite.print("[ MAP VIEW ]");
        else if (defenderState == NODE_SELECT) sprite.print("[ NODE SEL ]");
        else if (defenderState == TOOL_SELECT) sprite.print("[ TOOLS ]");

        sprite.setTextColor(TFT_WHITE);
        sprite.setCursor(240, 5);
        sprite.printf("L:%d S:%d P:%d", nodeLockUsage, speedBoostUsage, pingScanUsage);

        // BOTTOM HUD — NODE SELECT
        if (defenderState == NODE_SELECT) {
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

        // BOTTOM HUD — TOOL SELECT
        if (defenderState == TOOL_SELECT) {
            sprite.fillRect(0, 195, 320, 45, TFT_BLACK);
            sprite.drawRect(0, 195, 320, 45, TFT_CYAN);

            const char* toolNames[] = {"NODE LOCK", "SPEED BOOST", "PING SCAN"};
            int toolUsages[]        = {nodeLockUsage, speedBoostUsage, pingScanUsage};

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
                sprite.setCursor(4, 205);   sprite.print("<");
                sprite.setCursor(312, 205); sprite.print(">");
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

        // PING SCAN PULSE
        if (pingScanActive && hackerPosition >= 0) {
            int pingTarget = (spoofedHackerPosition >= 0) ? spoofedHackerPosition : hackerPosition;
            Node& pn = nodes[pingTarget];
            int hx = (int)(pn.worldX - cameraX);
            int hy = (int)(pn.worldY - cameraY);

            if (hx >= -20 && hx <= 340 && hy >= -20 && hy <= 260) {
                float pulse     = sin(millis() / 150.0f);
                int pulseRadius = 16 + (int)(pulse * 6);
                sprite.drawCircle(hx, hy, pulseRadius,     TFT_RED);
                sprite.drawCircle(hx, hy, pulseRadius + 3, TFT_RED);
                sprite.drawCircle(hx, hy, pulseRadius + 6, 0x7800);
            }
        }
    }

    sprite.pushSprite(0, 0);
}
