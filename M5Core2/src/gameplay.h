#pragma once
#include "game_state.h"

extern unsigned long gameOverTimestamp;

void handleWaitingToConnect();
void handleHackerSelect();
void handleGameplay();
void handleGameOver();
void handleHackerTurn();
void handleDefenderTurn();
