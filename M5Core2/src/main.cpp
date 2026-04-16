#include <Arduino.h>
#include <M5Core2.h>
#include <Adafruit_seesaw.h>
#include <EEPROM.h>
#include <BLEDevice.h>
#include "game_state.h"
#include "ble_server.h"
#include "renderer.h"
#include "gameplay.h"
#include "wifi_gcp.h"
#include "map_data.h"

Adafruit_seesaw gamepad;

uint32_t button_mask = (1UL << 6)  | (1UL << 2)  |
                       (1UL << 16) | (1UL << 5)  |
                       (1UL << 1)  | (1UL << 0);

void setup() {
    M5.begin();
    Serial.begin(115200);

    connectWiFi();

    if (!gamepad.begin(0x50)) {
        Serial.println("Seesaw not found");
        while (1);
    }
    gamepad.pinModeBulk(button_mask, INPUT_PULLUP);
    gamepad.setGPIOInterrupts(button_mask, 1);

    sprite.createSprite(320, 240);

    initializeSelectedMap();
    mapNodeCount = (selectedMap == 0) ? 24 : 25;

    // Persistent random seed
    int seedAddress = 0;
    long seed = EEPROM.read(seedAddress);
    randomSeed(seed);
    EEPROM.write(seedAddress, seed + 1);

    BLEDevice::init("HACKER_DEFENDER_GAME");
    startBleServer();

}

void loop() {
    M5.update();
    switch (currentStatus) {
        case WAITING_TO_CONNECT: handleWaitingToConnect(); break;
        case MAP_SELECT:         handleMapSelect(); break;
        case HACKER_SELECT:      handleHackerSelect();     break;
        case GAME_IN_PROGRESS:   handleGameplay();         break;
        case GAME_OVER:          handleGameOver();         break;
        case LEADERBOARD:        handleLeaderboard();      break;
    }
    drawScreen();
}
