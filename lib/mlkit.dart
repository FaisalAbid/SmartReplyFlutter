import 'package:flutter/services.dart';

class Smartreply {
  static const MethodChannel _channel =
      const MethodChannel('plugins.flutter.io/mlkit');

  static suggest() async {
    var resp = await _channel.invokeMethod("suggest");

    return resp;
  }

  static clear() {
    _channel.invokeMethod("clear");
  }

  static addChat(String message, String remoteUserId) {
    if (remoteUserId == null) {
      _channel.invokeMethod("createForLocalUser", {
        "message": message,
        "userId": remoteUserId,
        "time": new DateTime.now().millisecondsSinceEpoch
      });
    } else {
      _channel.invokeMethod("createForRemoteUser", {
        "message": message,
        "time": new DateTime.now().millisecondsSinceEpoch,
        "userId": remoteUserId
      });
    }
  }
}
