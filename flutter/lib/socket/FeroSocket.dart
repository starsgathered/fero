import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fero_sync/policies/backoff.dart';
import 'package:fero_sync/socket/message-dto.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef OnMessageReceived = void Function(MessageDto message);

class FeroSocketService {
  static final FeroSocketService _instance = FeroSocketService._internal();
  factory FeroSocketService() => _instance;

  WebSocketChannel? _channel;
  OnMessageReceived? onMessageReceived;

  // Connection info
  String? _host;
  int? _port;
  bool _useHttps = false;
  final String _namespace = '/fero';

  // Heartbeat & reconnect
  Timer? _pingTimer;
  bool _manuallyDisconnected = false;
  late RetryPolicy retryPolicy;
  final List<MessageDto> _pendingMessages = [];
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  FeroSocketService._internal() {
    retryPolicy = RetryPolicy(
      backoff: ExponentialBackoffStrategy(baseMillis: 500, maxMillis: 30000),
      maxRetries: 10,
    );
  }

  /// Connect to WebSocket
  void connect({
    required String host,
    int? port,
    bool useHttps = false,
  }) async {
    _host = host;
    _port = port;
    _useHttps = useHttps;
    _manuallyDisconnected = false;

    if (!await _hasInternet()) {
      debugPrint('[FeroSocket] No internet, waiting to connect...');
      _listenToConnectivity();
      return;
    }

    _connectInternal();
  }

  /// Internal connection
  void _connectInternal() {
    if (_host == null) return;

    final scheme = _useHttps ? 'wss' : 'ws';
    final portPart = _port != null ? ':$_port' : '';
    final uri = Uri.parse('$scheme://$_host$portPart$_namespace');

    try {
      _channel?.sink.close(); // close existing
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: _onError,
        cancelOnError: true,
      );

      _startHeartbeat();
      _flushPendingMessages();

      debugPrint('[FeroSocket] Connected to $uri');
    } catch (e) {
      debugPrint('[FeroSocket] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  /// Connectivity listener for automatic reconnect
  void _listenToConnectivity() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      // Check if any of the network types is online
      final isOnline = results.any((r) =>
          r != ConnectivityResult.wifi || r != ConnectivityResult.mobile);
      if (isOnline && !_manuallyDisconnected) {
        debugPrint('[FeroSocket] Internet available, trying reconnect...');
        _connectInternal();
      }
    });
  }

  Future<bool> _hasInternet() async {
    final results = await Connectivity().checkConnectivity();
    final isOnline = results.any(
        (r) => r != ConnectivityResult.wifi || r != ConnectivityResult.mobile);

    return isOnline;
  }

  void _onMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message);
      final dto = MessageDto.fromJson(decoded);
      onMessageReceived?.call(dto);
    } catch (_) {
      debugPrint('[FeroSocket] Raw message: $message');
    }
  }

  void _onDisconnected() {
    debugPrint('[FeroSocket] Disconnected');
    _stopHeartbeat();
    _scheduleReconnect();
  }

  void _onError(error) {
    debugPrint('[FeroSocket] Error: $error');
    _stopHeartbeat();
    _scheduleReconnect();
  }

  /// Send message
  void sendMessage(MessageDto message) {
    if (_channel == null) {
      _pendingMessages.add(message);
      debugPrint('[FeroSocket] Queued message, connection not ready');
      return;
    }

    try {
      _channel!.sink.add(jsonEncode(message.toJson()));
    } catch (_) {
      _pendingMessages.add(message);
      debugPrint('[FeroSocket] Queued message due to send error');
    }
  }

  void _flushPendingMessages() {
    for (var msg in _pendingMessages) {
      sendMessage(msg);
    }
    _pendingMessages.clear();
  }

  /// Disconnect manually
  void disconnect() {
    _manuallyDisconnected = true;
    _stopHeartbeat();
    _channel?.sink.close();
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _stopHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _scheduleReconnect() {
    // Agar manually disconnected hai, to reconnect mat karo
    if (_manuallyDisconnected) return;

    // Attempt reconnect using retryPolicy
    retryPolicy.attempt(
      () async {
        if (_manuallyDisconnected) return;

        debugPrint('[FeroSocket] Attempting reconnect...');
        _connectInternal();
      },
      isCancelled: () => _manuallyDisconnected,
    );
  }
}
