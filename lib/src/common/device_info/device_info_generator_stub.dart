import 'dart:ui' show SingletonFlutterWindow;
import 'package:wiredash/src/common/device_info/device_info_generator.dart';
import 'package:wiredash/src/common/utils/build_info.dart';

DeviceInfoGenerator createDeviceInfoGenerator(
  Future<DeviceInfoPlus> info,
  SingletonFlutterWindow window,
) {
  throw UnsupportedError(
    'Cannot create a Device Info Generator without dart:html or dart:io',
  );
}
