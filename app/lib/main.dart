import 'dart:async';

import 'package:flutter/material.dart';

import 'ble_link.dart';
import 'board_link.dart';
import 'wifi_link.dart';

/// A tiny wireless terminal for Arduino-compatible boards.
///
/// WiFi: flash board/wifi_serial/wifi_serial.ino, then type the IP address
/// it prints in the Serial Monitor.
/// Bluetooth: flash board/ble_serial/ble_serial.ino and tap Connect.
void main() => runApp(const WirelessTerminalApp());

class WirelessTerminalApp extends StatelessWidget {
  const WirelessTerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wireless Terminal',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const TerminalPage(),
    );
  }
}

enum Pipe { wifi, bluetooth }

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  Pipe _pipe = Pipe.wifi;
  BoardLink? _link;
  StreamSubscription<String>? _linesSub;
  bool _busy = false;
  String _status = 'Disconnected';
  final List<String> _log = [];
  final TextEditingController _ip = TextEditingController(text: '192.168.1.50');
  final TextEditingController _input = TextEditingController();

  Future<void> _connect() async {
    if (_link != null || _busy) return;
    setState(() {
      _busy = true;
      _status = _pipe == Pipe.wifi
          ? 'Connecting to ${_ip.text.trim()}...'
          : 'Looking for your board...';
    });
    try {
      final BoardLink link = _pipe == Pipe.wifi
          ? await WifiLink.connect(_ip.text.trim())
          : await BleLink.connect();
      _linesSub = link.lines.listen(
        (line) => _addLog('← $line'),
        onError: (Object e) => _setStatus('Error: $e'),
        onDone: _onLinkClosed,
      );
      _link = link;
      _setStatus(
        _pipe == Pipe.wifi ? 'Connected over WiFi' : 'Connected over Bluetooth',
      );
    } catch (e) {
      _setStatus('Could not connect: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send(String text) async {
    final BoardLink? link = _link;
    final String line = text.trim();
    if (link == null || line.isEmpty) return;
    try {
      await link.send(line);
      _addLog('→ $line');
      _input.clear();
    } catch (e) {
      _setStatus('Could not send: $e');
    }
  }

  Future<void> _disconnect() async {
    final BoardLink? link = _link;
    _link = null;
    await _linesSub?.cancel();
    _linesSub = null;
    await link?.close();
    _setStatus('Disconnected');
  }

  /// The board went away: it was reset, lost power, or walked out of range.
  void _onLinkClosed() {
    _link = null;
    _linesSub = null;
    _setStatus('Connection lost');
  }

  void _addLog(String line) {
    if (!mounted) return;
    setState(() {
      _log.add(line);
      if (_log.length > 200) _log.removeAt(0);
    });
  }

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() => _status = status);
  }

  @override
  void dispose() {
    _disconnect();
    _ip.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool connected = _link != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wireless Terminal'),
        actions: [
          TextButton(
            onPressed: _busy ? null : (connected ? _disconnect : _connect),
            child: Text(connected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<Pipe>(
              segments: const [
                ButtonSegment(value: Pipe.wifi, icon: Icon(Icons.wifi), label: Text('WiFi')),
                ButtonSegment(value: Pipe.bluetooth, icon: Icon(Icons.bluetooth), label: Text('Bluetooth')),
              ],
              selected: {_pipe},
              onSelectionChanged: connected || _busy
                  ? null
                  : (selection) => setState(() => _pipe = selection.first),
            ),
          ),
          if (_pipe == Pipe.wifi)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                controller: _ip,
                enabled: !connected && !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Board's IP address"),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: connected ? Colors.green.shade50 : Colors.grey.shade200,
            child: Text(_status),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _log.length,
              itemBuilder: (context, i) => Text(
                _log[i],
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                OutlinedButton(onPressed: connected ? () => _send('LED ON') : null, child: const Text('LED ON')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: connected ? () => _send('LED OFF') : null, child: const Text('LED OFF')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: connected,
                    decoration: const InputDecoration(hintText: 'Type a message'),
                    onSubmitted: _send,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: connected ? () => _send(_input.text) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
