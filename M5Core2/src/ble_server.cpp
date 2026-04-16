#include "ble_server.h"
#include "game_state.h"

static BLEUUID SERVICE_UUID("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
static BLEUUID CHAR_DEFENDER_UUID("beb5483e-36e1-4688-b7f5-ea07361b26a8");
static BLEUUID CHAR_HACKER_UUID("beb5483e-36e1-4688-b7f5-ea07361b26a9");

BLEServer*         bleServer     = nullptr;
BLEService*        bleService    = nullptr;
BLECharacteristic* defenderChar  = nullptr;
BLECharacteristic* hackerChar    = nullptr;

class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) override {
        (void)pServer;
        deviceConnected = true;
        currentStatus   = MAP_SELECT;
        Serial.println("[SERVER] Client connected!");
    }

    void onDisconnect(BLEServer* pServer) override {
        (void)pServer;
        deviceConnected = false;
        currentStatus   = WAITING_TO_CONNECT;
        restartAdvertising();
    }
};

class HackerWriteCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) override {
        String uuid  = pCharacteristic->getUUID().toString().c_str();
        String value = pCharacteristic->getValue().c_str();

        if (!uuid.equalsIgnoreCase(CHAR_HACKER_UUID.toString().c_str())) return;

        int pipeIndex   = value.lastIndexOf('|');
        int nodeId      = value.substring(1, pipeIndex).toInt();
        String tool     = value.substring(value.indexOf(':') + 1);

        hackerPosition = nodeId;
        Serial.printf("[SERVER] Hacker moved to node: %d\n", hackerPosition);
        Serial.printf("[SERVER] Full payload received: %s\n", value.c_str());

        if (nodes[hackerPosition].type == CORE) {
            result        = HACKER_WIN;
            currentStatus = GAME_OVER;
            Serial.println("[SERVER] Hacker reached CORE — Hacker wins!");
        }

        if (tracePositions[0] == hackerPosition || tracePositions[1] == hackerPosition) {
            result        = DEFENDER_WIN;
            currentStatus = GAME_OVER;
            Serial.println("[SERVER] DEFENDER WIN - hacker walked into trace");
        }

        currentTurn = DEFENDER_TURN;

        // Tick spoof counter down each hacker move
        if (hackerSpoofActive) {
            spoofTurnsRemaining--;
            if (spoofTurnsRemaining <= 0) {
                hackerSpoofActive     = false;
                spoofedHackerPosition = -1;
                Serial.println("[SERVER] Spoof expired");
            }
        }

        if (pingScanActive) {
            pingScanRevealTurns--;
            if (pingScanRevealTurns <= 0) {
                pingScanActive   = false;
                pingScanCooldown = false;
                spoofedHackerPosition = -1;
            }
        }

        if (tool != "none") {
            int colonIdx   = tool.indexOf(':');
            String toolName = (colonIdx >= 0) ? tool.substring(0, colonIdx) : tool;
            int toolTarget  = (colonIdx >= 0) ? tool.substring(colonIdx + 1).toInt() : -1;

            Serial.printf("[SERVER] Tool used: %s target: %d\n", toolName.c_str(), toolTarget);

            if (toolName == "crack" && toolTarget >= 0) {
                nodes[toolTarget].isLocked = false;
                Serial.printf("[SERVER] Node %d unlocked by Crack\n", toolTarget);
            } else if (toolName == "tunnel" && toolTarget >= 0 && toolTarget <= 3) {
                if (hackerPosition >= 0) nodes[hackerPosition].occupant = NONE;
                hackerPosition = toolTarget;
                nodes[hackerPosition].occupant = HACKER;
                Serial.printf("[SERVER] Hacker tunneled to entry node %d\n", hackerPosition);
            } else if (toolName == "spoof") {
                hackerSpoofActive = true;
                spoofTurnsRemaining   = 1;
                Serial.println("[SERVER] Spoof activated");
                if (toolTarget >= 0 && toolTarget < mapNodeCount) {
                    spoofedHackerPosition = toolTarget;
                }
                Serial.printf("[SERVER] Spoof activated, fake node: %d\n", spoofedHackerPosition);
            }
        }
    }
};

void startBleServer() {
    bleServer = BLEDevice::createServer();
    bleServer->setCallbacks(new ServerCallbacks());

    bleService   = bleServer->createService(SERVICE_UUID);
    defenderChar = bleService->createCharacteristic(
        CHAR_DEFENDER_UUID,
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_NOTIFY |
        BLECharacteristic::PROPERTY_INDICATE);
    defenderChar->addDescriptor(new BLE2902());
    defenderChar->setValue("T-1,-1|L-1|P0|SPLAY");

    hackerChar = bleService->createCharacteristic(
        CHAR_HACKER_UUID,
        BLECharacteristic::PROPERTY_WRITE);
    hackerChar->setCallbacks(new HackerWriteCallbacks());

    bleService->start();
    restartAdvertising();
}

void restartAdvertising() {
    BLEAdvertising* advertising = BLEDevice::getAdvertising();
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
    if (!deviceConnected || defenderChar == nullptr) return;

    String payload = "T" + String(tracePositions[0]) + "," + String(tracePositions[1]);

    int lockedNode = -1;
    for (int i = 0; i < mapNodeCount; i++) {
        if (nodes[i].isLocked) { lockedNode = i; break; }
    }
    payload += "|L" + String(lockedNode);
    payload += pingScanActive ? "|P1" : "|P0";
    payload += "|M" + String(selectedMap);

    if (currentStatus == GAME_OVER) {
        payload += (result == DEFENDER_WIN) ? "|SWIN" : "|HWIN";
    } else {
        payload += "|SPLAY";
    }

    defenderChar->setValue(payload.c_str());
    defenderChar->notify();
    Serial.printf("[SERVER] Sent: %s\n", payload.c_str());
}
