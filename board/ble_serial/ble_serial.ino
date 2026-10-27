// Bluetooth (BLE) serial for the Wireless Terminal app.
// Works on ESP32 boards with Bluetooth LE: ESP32, S3, C3, C6.
// Not the S2: it has no Bluetooth.
//
// It uses the Nordic UART Service, the usual way to do
// "serial over BLE": one service, with one characteristic
// for each direction.
//
// If the Arduino IDE says the sketch is too big:
// Tools > Partition Scheme > Huge APP.

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>

#define SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define RX_UUID      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define TX_UUID      "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
// RX: the phone writes here. TX: the board notifies here.

// The LED on most ESP32 dev boards. Change it for yours.
const int LED_PIN = 2;
BLECharacteristic* tx;

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

// Sends one line to the phone as a notification.
void reply(String line) {
  line += "\n";
  tx->setValue((uint8_t*)line.c_str(), line.length());
  tx->notify();
}

// Runs every time the phone writes to RX.
class RxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    String message = c->getValue().c_str();
    reply(handle(message));
  }
};

// Advertise again after the phone disconnects,
// so it can find the board.
class ServerCallbacks : public BLEServerCallbacks {
  void onDisconnect(BLEServer* server) override {
    BLEDevice::startAdvertising();
  }
};

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);

  BLEDevice::init("My Board");
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService* service = server->createService(SERVICE_UUID);
  tx = service->createCharacteristic(
      TX_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  tx->addDescriptor(new BLE2902());  // lets the phone subscribe
  BLECharacteristic* rx = service->createCharacteristic(
      RX_UUID, BLECharacteristic::PROPERTY_WRITE);
  rx->setCallbacks(new RxCallbacks());
  service->start();

  // Advertise the service ID so the app can find the board.
  BLEDevice::getAdvertising()->addServiceUUID(SERVICE_UUID);
  BLEDevice::startAdvertising();
  Serial.println("Advertising as \"My Board\"");
}

void loop() {}
