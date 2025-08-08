import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SocketRequest {
  final String action;
  final Map<String, dynamic> data;

  SocketRequest({required this.action, required this.data});

  Map<String, dynamic> toJson() => {
    'action': action,
    'data': data,
  };

  factory SocketRequest.fromJson(Map<String, dynamic> json) {
    return SocketRequest(
      action: json['action'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }
}

class SocketResponse {
  final bool isSuccess;
  final String message;
  final dynamic data;

  SocketResponse({
    required this.isSuccess,
    required this.message,
    this.data,
  });

  factory SocketResponse.fromJson(Map<String, dynamic> json) {
    return SocketResponse(
      isSuccess: json['status'] == 'success',
      message: json['message'] ?? '',
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() => {
    'status': isSuccess ? 'success' : 'error',
    'message': message,
    'data': data,
  };
}

class SocketService {
  Socket? _socket;
  final String host;
  final int port;

  SocketService({this.host = '192.168.43.60', this.port = 12345});

  bool get isConnected => _socket != null;

  Future<void> connect() async {
    if (_socket != null) return;
    try {
      _socket = await Socket.connect(host, port).timeout(const Duration(seconds: 5));
      print("Connected to $host:$port");
    } catch (e) {
      throw Exception("Failed to connect to server: $e");
    }
  }

  Future<SocketResponse> send(SocketRequest request) async {
    if (_socket == null) {
      await connect();
    }

    try {
      final jsonStr = jsonEncode(request.toJson());
      _socket!.write(jsonStr + '\n');

      final completer = Completer<String>();
      late StreamSubscription sub;

      sub = _socket!
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        completer.complete(line);
        sub.cancel();
      }, onError: (e) {
        completer.completeError(Exception("Socket error: $e"));
        sub.cancel();
      });

      final rawResponse = await completer.future.timeout(const Duration(seconds: 5));
      final decoded = jsonDecode(rawResponse);

      return SocketResponse.fromJson(decoded);
    } catch (e) {
      _socket?.destroy();
      _socket = null;
      throw Exception("Request failed: $e");
    }
  }

  void close() {
    _socket?.destroy();
    _socket = null;
    print("Socket closed");
  }
}