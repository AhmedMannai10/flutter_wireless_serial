/// Anything that carries lines of text between the app and the board.
///
/// The screen only talks to this interface, so it doesn't care whether the
/// bytes travel over WiFi or Bluetooth.
abstract class BoardLink {
  /// Complete lines from the board, without the newline.
  /// The stream ends when the connection drops.
  Stream<String> get lines;

  /// Sends one line. The newline is added for you.
  Future<void> send(String line);

  /// Closes the connection.
  Future<void> close();
}
