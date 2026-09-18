import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/shuttle.dart';

class WebSocketService {
  final String wsUrl;
  WebSocketChannel? _channel;
  final StreamController<List<ShuttleModel>> _shuttleStreamController =
      StreamController<List<ShuttleModel>>.broadcast();

  bool _isConnected = false;
  Timer? _reconnectTimer;

  WebSocketService({this.wsUrl = 'ws://127.0.0.1:8000/ws/shuttles'});

  Stream<List<ShuttleModel>> get shuttleStream => _shuttleStreamController.stream;
  bool get isConnected => _isConnected;

  void connect() {
    _reconnectTimer?.cancel();
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            if (data['shuttles'] is List) {
              final list = (data['shuttles'] as List<dynamic>)
                  .map((s) => ShuttleModel.fromJson(s as Map<String, dynamic>))
                  .toList();
              _shuttleStreamController.add(list);
            }
          } catch (e) {
            // Handle parsing error
          }
        },
        onError: (error) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _channel = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      connect();
    });
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _shuttleStreamController.close();
  }
}
