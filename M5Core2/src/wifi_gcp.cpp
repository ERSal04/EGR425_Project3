#include "wifi_gcp.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>

int  gcpHackerWins   = 0;
int  gcpDefenderWins = 0;
bool gcpDataReady    = false;
bool gcpPostDone     = false;

void connectWiFi() {
    Serial.printf("[WIFI] Connecting to %s", WIFI_SSID);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
        delay(500);
        Serial.print(".");
        attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("\n[WIFI] Connected — IP: %s\n", WiFi.localIP().toString().c_str());
    } else {
        Serial.println("\n[WIFI] Failed to connect");
    }
}

void postWinToGCP(const char* winner) {
    BLEDevice::deinit(true);
    delay(100);

    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("[GCP] Not connected to WiFi — skipping POST");
        gcpPostDone = true;
        return;
    }

    HTTPClient http;
    http.begin(GCP_RECORD_URL);
    http.addHeader("Content-Type", "application/json");

    String body = "{\"winner\":\"";
    body += winner;
    body += "\"}";

    int code = http.POST(body);
    Serial.printf("[GCP] POST recordWin → %d\n", code);
    http.end();
    gcpPostDone = true;
}

void fetchLeaderboard() {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("[GCP] Not connected to WiFi — skipping GET");
        gcpDataReady = true;
        return;
    }

    HTTPClient http;
    http.begin(GCP_LEADERBOARD_URL);

    int code = http.GET();
    Serial.printf("[GCP] GET leaderboard → %d\n", code);

    if (code == 200) {
        String response = http.getString();
        Serial.printf("[GCP] Response: %s\n", response.c_str());

        StaticJsonDocument<128> doc;
        DeserializationError err = deserializeJson(doc, response);
        if (!err) {
            gcpHackerWins   = doc["hackerWins"]   | 0;
            gcpDefenderWins = doc["defenderWins"] | 0;
            gcpDataReady    = true;
        } else {
            Serial.println("[GCP] JSON parse error");
            gcpDataReady = true;
        }
    } else {
        Serial.println("[GCP] GET failed — showing zeros");
        gcpDataReady = true;
    }
    http.end();
}
