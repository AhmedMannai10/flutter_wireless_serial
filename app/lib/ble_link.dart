import 'dart:async';
import 'dart:convert';

import 'package:universal_ble/universal_ble.dart';

import 'board_link.dart';

/// Talks to the board over Bluetooth Low Energy, using the Nordic UART Service:
/// one service with two characteristics, one for each direction.
///
/// Pair it with board/ble_serial/ble_serial.ino.
class BleLink implements BoardLink {
  static const service = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const rxUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // the phone writes here
  static const txUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // the board notifies here

  BleLink._(this._device, this._rx, BleCharacteristic tx) {
    // Notifications arrive in packets, and one line can be split across
    // several of them, so split the bytes at each newline, exactly like WiFi.
    final values = tx.onValueReceived
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (!_lines.isClosed) _lines.add(line);
        });
    // End the stream when the board disconnects.
    final connection = _device.connectionStream.listen((connected) {
      if (!connected) _lines.close();
    });
    _lines.onCancel = () async {
      await values.cancel();
      await connection.cancel();
    };
  }

  /// Finds the first board advertising the UART service and connects to it.
  static Future<BleLink> connect() async {
    // 1. Scan for a board that advertises the UART service.
    final firstResult = UniversalBle.scanStream.first; // listen before scanning
    await UniversalBle.startScan(
      scanFilter: ScanFilter(withServices: [service]),
    );
    final BleDevice device;
    try {
      device = await firstResult.timeout(const Duration(seconds: 10));
    } finally {
      await UniversalBle.stopScan();
    }

    // 2. Connect, then ask for bigger packets. Until you do, Android sends
    //    20 bytes per packet. iPhones negotiate this on their own.
    await device.connect();
    await device.requestMtu(247);

    // 3. Grab both characteristics and subscribe to the board's replies.
    final rx = await device.getCharacteristic(rxUuid, service: service);
    final tx = await device.getCharacteristic(txUuid, service: service);
    final link = BleLink._(device, rx, tx);
    await tx.notifications.subscribe();
    return link;
  }

  final BleDevice _device;
  final BleCharacteristic _rx;
  final StreamController<String> _lines = StreamController<String>();

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<void> send(String line) => _rx.write(utf8.encode('$line\n'));

  @override
  Future<void> close() async {
    await _device.disconnect();
    await _lines.close();
  }
}
