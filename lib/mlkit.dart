import 'package:flutter/services.dart';

class Smartreply {
  static const MethodChannel _channel =
      const MethodChannel('plugins.flutter.io/mlkit');

  static suggest() async {
    var resp = await _channel.invokeMethod("suggest");
    print(resp.length);
    return resp;
  }

  static clear() {
    _channel.invokeMethod("clear");
  }

  static addChat(
      String message, String remoteUserId, DateTime date, bool isLocalUser) {
    if (isLocalUser) {
      _channel.invokeMethod("createForLocalUser", {
        "message": message,
        "userId": remoteUserId,
        "time": date.millisecondsSinceEpoch
      });
    } else {
      _channel.invokeMethod("createForRemoteUser", {
        "message": message,
        "time": date.millisecondsSinceEpoch,
        "userId": remoteUserId
      });
    }
  }
}
