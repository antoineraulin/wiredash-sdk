import 'dart:io';
import 'dart:ui' show SingletonFlutterWindow;
import 'package:wiredash/src/common/device_info/device_info.dart';
import 'package:wiredash/src/common/device_info/device_info_generator.dart';
import 'package:wiredash/src/common/utils/build_info.dart';

class _DartIoDeviceInfoGenerator implements DeviceInfoGenerator {
  _DartIoDeviceInfoGenerator(
    this.info,
    this.window,
  );

  final Future<DeviceInfoPlus> info;
  final SingletonFlutterWindow window;

  @override
  Future<DeviceInfo> generate() {
    return DeviceInfoGenerator.baseDeviceInfo(info, window);
  }
}

/// Called by [DeviceInfoGenerator] factory constructor
DeviceInfoGenerator createDeviceInfoGenerator(
  Future<DeviceInfoPlus> buildInfo,
  SingletonFlutterWindow window,
) {
  return _DartIoDeviceInfoGenerator(buildInfo, window);
}
