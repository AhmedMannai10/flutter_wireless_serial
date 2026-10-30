# Flutter wireless serial: talk to an ESP32 over WiFi or Bluetooth

A tiny Flutter app and two ESP32 sketches that send lines of text back and forth, with no cable.
Commands: `LED ON`, `LED OFF`, and anything else is echoed back.

```
app/                   Flutter app (Android + iOS): one screen, WiFi or Bluetooth
  lib/board_link.dart    the interface the screen talks to: lines, send, close
  lib/wifi_link.dart     WiFi: a plain TCP socket (dart:io, no package)
  lib/ble_link.dart      Bluetooth LE: Nordic UART Service via universal_ble
  test/                  socket tests against a fake board
board/wifi_serial/     ESP32 sketch: joins your WiFi, TCP server on port 3333
board/ble_serial/      ESP32 sketch: BLE Nordic UART Service
```

## WiFi
1. Open `board/wifi_serial/wifi_serial.ino`, set your WiFi name and password, upload.
   Most ESP32 boards only join **2.4 GHz** networks.
2. Open the Serial Monitor at 115200 baud and note the IP address.
3. Run the app, pick **WiFi**, type the IP, tap **Connect**.

## Bluetooth (BLE)
Needs an ESP32 with Bluetooth LE (ESP32, S3, C3, C6; the S2 has no Bluetooth).
1. Upload `board/ble_serial/ble_serial.ino`. If the Arduino IDE says the sketch is too big:
   Tools > Partition Scheme > Huge APP.
2. Optional but quick: test it with nRF Connect. Connect to "My Board" and write `LED ON` to the RX characteristic.
3. Run the app, pick **Bluetooth**, tap **Connect**. It connects to the first board advertising the UART service.

## How it fits together
Every message ends with a newline, on both sides. Bytes arrive in pieces over every transport,
so the app splits the incoming bytes at each newline (`cast` → `utf8.decoder` → `LineSplitter`).
The screen only talks to `BoardLink`; `WifiLink` and `BleLink` are the two implementations.

## If it doesn't work
**WiFi:** board on 2.4 GHz? Phone on the same network (guest networks often block devices from seeing each other)?
Right IP? For release builds, the `INTERNET` permission must be in `android/app/src/main/AndroidManifest.xml`
(debug builds get it for free). On iPhone, allow local network access.

**Bluetooth:** permissions allowed? Can nRF Connect see the board? Is another phone already connected
(the sketch takes one at a time)? Replies cut at 20 characters means the MTU wasn't raised.

**Both:** if the connection drops at the same moment every time, keep the Serial Monitor open.
A board that reboots shows up there.

## Notes
- BLE package: [universal_ble](https://pub.dev/packages/universal_ble) (BSD-3-Clause).
  flutter_blue_plus also works, but check its license first: commercial use needs a paid license.
- Board LED: pin 2 on most ESP32 dev boards. Change `LED_PIN` for yours.
- Tested so far: `flutter analyze`, the socket tests, a release APK build, and both sketches compiled
  with arduino-esp32 2.0.17 (ESP32 / ESP32-S2). Not yet tested on hardware.

## License
MIT. See [LICENSE](LICENSE).
