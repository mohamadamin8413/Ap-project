import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SocketRequest {
  final String action;
  final Map<String, dynamic> data;
  final String requestId;

  SocketRequest({required this.action, required this.data, required this.requestId});

  Map<String, dynamic> toJson() => {
    'action': action,
    'data': data,
    'requestId': requestId,
  };

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

  SocketResponse({
    required this.isSuccess,
    required this.message,
    this.data,
    this.requestId,
  });

  factory SocketResponse.fromJson(Map<String, dynamic> json) {
    return SocketResponse(
      isSuccess: json['status'] == 'success',
      message: json['message'] ?? '',
      data: json['data'],
      requestId: json['requestId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'status': isSuccess ? 'success' : 'error',
    'message': message,
    'data': data,
    'requestId': requestId,
  };
}

class SocketService {
  Socket? _socket;
  final String host;
  final int port;
  final StreamController<SocketResponse> _responseController = StreamController<SocketResponse>.broadcast();
  final Map<String, Completer<SocketResponse>> _requestCompleters = {};
  StreamSubscription? _socketSubscription;

  SocketService({this.host = '192.168.43.60', this.port = 12345}) {
    _connect();
  }

  bool get isConnected => _socket != null;

  Future<void> _connect() async {
    if (_socket != null) return;
    try {
      _socket = await Socket.connect(host, port).timeout(const Duration(seconds: 10));
      print("Connected to $host:$port");

      _socketSubscription?.cancel();
      _socketSubscription = _socket!
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
          try {
            final decoded = jsonDecode(line);
            final response = SocketResponse.fromJson(decoded);
            _responseController.add(response);
            if (response.requestId != null && _requestCompleters.containsKey(response.requestId)) {
              _requestCompleters[response.requestId]!.complete(response);
              _requestCompleters.remove(response.requestId);
            } else {
              print("No matching completer for requestId: ${response.requestId}");
            }
          } catch (e) {
            print("Failed to parse response: $e");
            _responseController.addError(Exception("Failed to parse response: $e"));
          }
        },
        onError: (e) {
          print("Socket error: $e");
          _responseController.addError(Exception("Socket error: $e"));
          _requestCompleters.forEach((id, completer) {
            completer.completeError(Exception("Socket error: $e"));
          });
          _requestCompleters.clear();
          _socket?.destroy();
          _socket = null;
          _socketSubscription?.cancel();
        },
        onDone: () {
          print("Socket closed by server");
          _responseController.close();
          _requestCompleters.forEach((id, completer) {
            completer.completeError(Exception("Socket closed by server"));
          });
          _requestCompleters.clear();
          _socket?.destroy();
          _socket = null;
          _socketSubscription?.cancel();
        },
        cancelOnError: false,
      );
    } catch (e) {
      print("Failed to connect to server: $e");
      _responseController.addError(Exception("Failed to connect to server: $e"));
      _socket?.destroy();
      _socket = null;
    }
  }

  Future<SocketResponse> send(SocketRequest request) async {
    if (_socket == null) {
      await _connect();
      if (_socket == null) {
        throw Exception("Failed to connect to server");
      }
    }

    try {
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();
      final requestWithId = SocketRequest(
        action: request.action,
        data: request.data,
        requestId: requestId,
      );

      final jsonStr = jsonEncode(requestWithId.toJson());
      print("Sending request: $jsonStr");
      _socket!.write(jsonStr + '\n');

      final completer = Completer<SocketResponse>();
      _requestCompleters[requestId] = completer;

      final response = await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
        _requestCompleters.remove(requestId);
        throw Exception("Request timed out");
      });
      print("Received response: ${response.toJson()}");
      return response;
    } catch (e) {
      print("Request failed: $e");
      _requestCompleters.remove(request.requestId);
      _socket?.destroy();
      _socket = null;
      throw Exception("Request failed: $e");
    }
  }

  Stream<SocketResponse> get responses => _responseController.stream;

  void close() {
    _socketSubscription?.cancel();
    _socket?.destroy();
    _socket = null;
    _responseController.close();
    _requestCompleters.clear();
    print("Socket closed");
  }
}