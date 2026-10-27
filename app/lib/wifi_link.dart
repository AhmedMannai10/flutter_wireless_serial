import 'dart:convert';
import 'dart:io';

import 'board_link.dart';

/// Talks to the board over WiFi, through a plain TCP socket.
///
/// Pair it with board/wifi_serial/wifi_serial.ino.
class WifiLink implements BoardLink {
  WifiLink._(this._socket)
    : lines = _socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

  /// Connects to the board. It prints its IP address in the Serial Monitor.
  static Future<WifiLink> connect(String ip, {int port = 3333}) async {
    final socket = await Socket.connect(
      ip,
      port,
      timeout: const Duration(seconds: 5),
    );
    return WifiLink._(socket);
  }

  final Socket _socket;

  @override
  final Stream<String> lines;

  @override
  Future<void> send(String line) async => _socket.write('$line\n');

  @override
  Future<void> close() async => _socket.destroy();
}
