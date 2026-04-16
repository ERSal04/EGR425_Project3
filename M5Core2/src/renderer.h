#pragma once
#include <Arduino.h>
#include <M5Core2.h>
#include "game_state.h"

extern TFT_eSprite sprite;

uint32_t getNodeColor(NodeType type);
int      getNodeRadius(NodeType type);
void     drawScreen();
