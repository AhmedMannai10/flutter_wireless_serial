// WiFi serial for the Wireless Terminal app.
// Works on ESP32 boards, including the S2, S3, C3 and C6.
//
// 1. Put your WiFi name and password below.
//    Most ESP32 boards only join 2.4 GHz networks.
// 2. Upload, open the Serial Monitor at 115200 baud,
//    and note the IP address it prints.
// 3. Type that IP address into the app and tap Connect.

#include <WiFi.h>

const char* WIFI_NAME     = "your-wifi";
const char* WIFI_PASSWORD = "your-password";

// The LED on most ESP32 dev boards. Change it for yours.
const int LED_PIN = 2;

WiFiServer server(3333);  // the app connects to this port
WiFiClient app;

// Same commands over WiFi and Bluetooth. Only the pipe changes.
String handle(String message) {
  message.trim();
  if (message == "LED ON") {
    digitalWrite(LED_PIN, HIGH);
    return "OK: LED is on";
  }
  if (message == "LED OFF") {
    digitalWrite(LED_PIN, LOW);
    return "OK: LED is off";
  }
  return "Got: " + message;
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);

  WiFi.begin(WIFI_NAME, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());

  server.begin();
}

void loop() {
  if (!app.connected()) {
    app = server.accept();  // wait for the app
    return;
  }
  if (app.available()) {
    // The app ends every message with '\n'.
    String message = app.readStringUntil('\n');
    // println adds the newline back.
    app.println(handle(message));
  }
}
