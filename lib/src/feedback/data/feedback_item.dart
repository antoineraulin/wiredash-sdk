import 'dart:convert';

import 'package:wiredash/src/common/device_info/device_info.dart';
import 'package:wiredash/src/version.dart';

/// Contains all relevant feedback information, both user-provided and automatically
/// inferred, that will be eventually sent to the Wiredash console.
class FeedbackItem {
  const FeedbackItem({
    required this.deviceInfo,
    required this.message,
    required this.type,
    this.sdkVersion = wiredashSdkVersion,
    this.attachmentPath,
  });

  final DeviceInfo deviceInfo;
  final String message;
  final String type;
  final int sdkVersion;
  final String? attachmentPath;

  FeedbackItem.fromJson(Map<String, dynamic> json)
      : deviceInfo =
            DeviceInfo.fromJson(json['deviceInfo'] as Map<String, dynamic>),
        message = json['message'] as String,
        type = json['type'] as String,
        sdkVersion = json['sdkVersion'] as int,
        attachmentPath = json['attachmentPath'] as String?;

  Map<String, dynamic> toJson() {
    return {
      'deviceInfo': deviceInfo.toJson(),
      'message': message,
      'type': type,
      'sdkVersion': sdkVersion,
    };
  }

  /// Encodes the fields for a multipart/form-data request
  Map<String, String?> toMultipartFormFields() {
    return {
      'deviceInfo': json.encode(deviceInfo.toJson()),
      'message': message,
      'type': type,
      'sdkVersion': sdkVersion.toString(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedbackItem &&
          runtimeType == other.runtimeType &&
          deviceInfo == other.deviceInfo &&
          message == other.message &&
          type == other.type &&
          sdkVersion == other.sdkVersion;

  @override
  int get hashCode =>
      deviceInfo.hashCode ^
      message.hashCode ^
      type.hashCode ^
      sdkVersion.hashCode;

  @override
  String toString() {
    return 'FeedbackItem{'
        'deviceInfo: $deviceInfo, '
        'message: $message, '
        'type: $type, '
        'sdkVersion: $sdkVersion, '
        '}';
  }
}
