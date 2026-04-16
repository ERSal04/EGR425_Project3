#pragma once
#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

extern BLEServer*         bleServer;
extern BLEService*        bleService;
extern BLECharacteristic* defenderChar;
extern BLECharacteristic* hackerChar;

void startBleServer();
void restartAdvertising();
void sendDefenderState();
