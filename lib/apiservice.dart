import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SocketRequest {
  final String action;
  final Map<String, dynamic> data;
  final String requestId;

  SocketRequest({required this.action, required this.data, required this.requestId});

  Map<String, dynamic> toJson() => {'action': action, 'data': data, 'requestId': requestId};

  factory SocketRequest.fromJson(Map<String, dynamic> json) {
    return SocketRequest(
      action: json['action'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      requestId: json['requestId'] ?? '',
    );
  }
}

class SocketResponse {
  final bool isSuccess;
  final String message;
  final dynamic data;
  final String? requestId;

  SocketResponse({required this.isSuccess, required this.message, this.data, this.requestId});

  factory SocketResponse.fromJson(Map<String, dynamic> json) {
    return SocketResponse(
      isSuccess: json['status'] == 'success',
      message: json['message'] ?? '',
      data: json['data'],
      requestId: json['requestId'],
    );
  }

  Map<String, dynamic> toJson() => {'status': isSuccess ? 'success' : 'error', 'message': message, 'data': data, 'requestId': requestId};
}

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService({String? host, int? port}) {
    if (host != null) _instance._host = host;
    if (port != null) _instance._port = port;
    return _instance;
  }
  SocketService._internal();

  String _host = '192.168.43.60';
  int _port = 12345;
  Socket? _socket;
  StreamSubscription? _socketSubscription;
  final StreamController<SocketResponse> _responseController = StreamController<SocketResponse>.broadcast();
  final Map<String, Completer<SocketResponse>> _requestCompleters = {};
  bool _isConnecting = false;
  Completer<void>? _connectCompleter;
  int _reconnectAttempts = 0;

  Stream<SocketResponse> get responses => _responseController.stream;
  bool get isConnected => _socket != null;

  Future<void> _connect({Duration timeout = const Duration(seconds: 10)}) async {
    if (_socket != null) return;
    if (_isConnecting) return _connectCompleter?.future ?? Future.value();
    _isConnecting = true;
    _connectCompleter = Completer<void>();
    try {
      _socket = await Socket.connect(_host, _port).timeout(timeout);
      _reconnectAttempts = 0;
      await _socketSubscription?.cancel();
      _socketSubscription = _socket!.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(_onLineReceived, onError: _onSocketError, onDone: _onSocketDone, cancelOnError: false);
      _connectCompleter?.complete();
    } catch (e) {
      _socket?.destroy();
      _socket = null;
      _connectCompleter?.completeError(e);
      rethrow;
    } finally {
      _isConnecting = false;
      _connectCompleter = null;
    }
  }

  void _onLineReceived(String line) {
    try {
      final decoded = jsonDecode(line);
      final response = SocketResponse.fromJson(Map<String, dynamic>.from(decoded));
      if (!_responseController.isClosed) _responseController.add(response);
      final rid = response.requestId;
      if (rid != null && _requestCompleters.containsKey(rid)) {
        final completer = _requestCompleters.remove(rid);
        completer?.complete(response);
      }
    } catch (e) {
      if (!_responseController.isClosed) _responseController.addError(Exception('Failed to parse response: $e'));
    }
  }

  void _onSocketError(Object error) {
    _completeAllPendingWithError(Exception('Socket error: $error'));
    _cleanupSocket();
  }

  void _onSocketDone() {
    _completeAllPendingWithError(Exception('Socket closed by server'));
    _cleanupSocket();
  }

  void _completeAllPendingWithError(Object error) {
    if (_requestCompleters.isNotEmpty) {
      _requestCompleters.forEach((id, completer) {
        try {
          completer.completeError(error);
        } catch (_) {}
      });
      _requestCompleters.clear();
    }
  }

  void _cleanupSocket() {
    try {
      _socketSubscription?.cancel();
    } catch (_) {}
    try {
      _socket?.destroy();
    } catch (_) {}
    _socketSubscription = null;
    _socket = null;
  }

  Future<SocketResponse> send(SocketRequest request, {Duration timeout = const Duration(seconds: 20)}) async {
    if (_socket == null) {
      try {
        await _connect();
      } catch (e) {
        throw Exception('Failed to connect to server: $e');
      }
    }
    final requestId = DateTime.now().millisecondsSinceEpoch.toString() + '-' + _randomSuffix();
    final requestWithId = SocketRequest(action: request.action, data: request.data, requestId: requestId);
    final jsonStr = jsonEncode(requestWithId.toJson());
    final completer = Completer<SocketResponse>();
    _requestCompleters[requestId] = completer;
    try {
      _socket!.write(jsonStr + '\n');
      final response = await completer.future.timeout(timeout, onTimeout: () {
        _requestCompleters.remove(requestId);
        throw TimeoutException('Request timed out');
      });
      return response;
    } catch (e) {
      _requestCompleters.remove(requestId);
      try {
        _socket?.destroy();
      } catch (_) {}
      _socket = null;
      rethrow;
    }
  }

  String _randomSuffix() {
    final v = DateTime.now().microsecond;
    return v.toRadixString(16);
  }

  void close() {
    _completeAllPendingWithError(Exception('SocketService closed'));
    try {
      _socketSubscription?.cancel();
    } catch (_) {}
    try {
      _socket?.destroy();
    } catch (_) {}
    _socketSubscription = null;
    _socket = null;
    if (!_responseController.isClosed) _responseController.close();
    _requestCompleters.clear();
  }
}