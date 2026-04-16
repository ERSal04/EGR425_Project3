#pragma once
#include "game_state.h"

extern unsigned long gameOverTimestamp;

void handleWaitingToConnect();
void handleMapSelect();
void handleHackerSelect();
void handleGameplay();
void handleGameOver();
void handleLeaderboard();
void handleHackerTurn();
void handleDefenderTurn();
