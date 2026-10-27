import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wireless_terminal/wifi_link.dart';

/// A fake board on localhost that behaves like board/wifi_serial/wifi_serial.ino,
/// except that it deliberately splits its replies into awkward chunks.
Future<ServerSocket> fakeBoard(List<String> received) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((client) {
    var replying = Future<void>.value(); // one reply at a time, like the real board
    client
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((msg) {
      received.add(msg);
      final reply = msg == 'LED ON' ? 'OK: LED is on' : 'Got: $msg';
      // Arduino's println() ends lines with \r\n. Send it in two pieces.
      final bytes = utf8.encode('$reply\r\n');
      replying = replying.then((_) async {
        client.add(bytes.sublist(0, 6));
        await client.flush();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        client.add(bytes.sublist(6));
        await client.flush();
      });
    });
  });
  return server;
}

void main() {
  test('sends lines with a newline and reassembles chunked replies', () async {
    final received = <String>[];
    final board = await fakeBoard(received);
    final link = await WifiLink.connect('127.0.0.1', port: board.port);

    final replies = <String>[];
    final gotTwo = Completer<void>();
    link.lines.listen((line) {
      replies.add(line);
      if (replies.length == 2) gotTwo.complete();
    });

    // Two sends back to back, like a quick double tap.
    unawaited(link.send('LED ON'));
    unawaited(link.send('hello'));
    await gotTwo.future.timeout(const Duration(seconds: 3));

    expect(received, ['LED ON', 'hello']);
    expect(replies, ['OK: LED is on', 'Got: hello']);

    await link.close();
    await board.close();
  });

  test('the lines stream ends when the board drops the connection', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((client) => client.destroy());
    final link = await WifiLink.connect('127.0.0.1', port: server.port);
    await expectLater(link.lines, emitsDone);
    await server.close();
  });
}
