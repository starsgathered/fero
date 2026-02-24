import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fero_sync/socket/message-dto.dart';

typedef OnMessageReceived = void Function(MessageDto message);

enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class FeroSocketService {
  FeroSocketService._internal() {
    debugPrint('[FeroSocket] Initialized');
  }

  static final FeroSocketService _instance = FeroSocketService._internal();
  factory FeroSocketService() => _instance;

  WebSocketChannel? _channel;
  OnMessageReceived? onMessageReceived;

  final String _namespace = '/fero';
  String? _host;
  int? _port;
  bool _useHttps = false;
  bool _manuallyDisconnected = false;
  final List<MessageDto> _pendingMessages = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  SocketConnectionState _state = SocketConnectionState.disconnected;
  SocketConnectionState get state => _state;

  void _setState(SocketConnectionState newState) {
    debugPrint('[FeroSocket] State: $_state → $newState');
    _state = newState;
  }

  Future<void> connect({
    required String host,
    int? port,
    bool useHttps = false,
  }) async {
    _host = host;
    _port = port;
    _useHttps = useHttps;
    _manuallyDisconnected = false;

    if (!await _hasInternet()) {
      _listenToConnectivity();
      return;
    }
    _connectOnce();
  }

  void disconnect() {
    _manuallyDisconnected = true;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _channel?.sink.close();
    _channel = null;
    _setState(SocketConnectionState.disconnected);
    debugPrint('[FeroSocket] Disconnected manually');
  }

  void sendMessage(MessageDto message) {
    if (_state != SocketConnectionState.connected || _channel == null) {
      _pendingMessages.add(message);
      debugPrint(
          '[FeroSocket] Queued message. Pending: ${_pendingMessages.length}');
      return;
    }
    try {
      _channel!.sink.add(jsonEncode(message.toJson()));
      debugPrint('[FeroSocket] Sent: ${message.text}');
    } catch (e) {
      _pendingMessages.add(message);
      debugPrint('[FeroSocket] Failed send, queued: $e');
    }
  }

  Future<void> _connectOnce() async {
    if (_host == null || _manuallyDisconnected) return;

    _setState(SocketConnectionState.connecting);

    final scheme = _useHttps ? 'wss' : 'ws';
    final portPart = _port != null ? ':$_port' : '';
    final uri = Uri.parse('$scheme://$_host$portPart$_namespace');

    _channel?.sink.close();

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      _onMessage,
      onDone: _onDisconnected,
      onError: _onError,
      cancelOnError: true,
    );

    debugPrint('[FeroSocket] Attempting connection to $uri');
  }

  void _onMessage(dynamic message) {
    if (_state != SocketConnectionState.connected) {
      _setState(SocketConnectionState.connected);
      _flushPendingMessages();
    }
    try {
      final decoded = jsonDecode(message);
      final dto = MessageDto(
        text: decoded['text'] ?? '',
        userId: decoded['userId'] ?? 'server',
      );
      onMessageReceived?.call(dto);
      debugPrint('[FeroSocket] Received: ${dto.text}');
    } catch (_) {
      debugPrint('[FeroSocket] Raw: $message');
    }
  }

  void _onError(Object e) {
    if (_manuallyDisconnected) return;
    debugPrint('[FeroSocket] Error: $e');
    // No retry logic here
  }

  void _onDisconnected() {
    if (_manuallyDisconnected) return;
    debugPrint('[FeroSocket] Server closed connection');
    // No retry logic here
  }

  void _flushPendingMessages() {
    if (_channel == null) return;
    for (final msg in _pendingMessages) {
      try {
        _channel!.sink.add(jsonEncode(msg.toJson()));
      } catch (_) {
        break;
      }
    }
    _pendingMessages.clear();
  }

  Future<bool> _hasInternet() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet);
  }

  void _listenToConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final isOnline = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.ethernet);
      debugPrint('[FeroSocket] Connectivity changed. Online: $isOnline');
      if (isOnline &&
          !_manuallyDisconnected &&
          _state != SocketConnectionState.connected) {
        _connectOnce();
      }
    });
  }
}
