import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<DeviceInfoPlus> getDeviceInfo() async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  final PackageInfo packageInfo = await PackageInfo.fromPlatform();
  if (Platform.isAndroid) {
    final AndroidDeviceInfo info = await deviceInfo.androidInfo;
    return DeviceInfoPlus(
      emulator: !(info.isPhysicalDevice ?? true),
      os: 'Android',
      model: info.model,
      brand: info.brand ?? info.manufacturer,
      uuid: info.androidId,
      osVersion: info.version.sdkInt.toString(),
      appVersion: packageInfo.version,
      appBuildNumber: packageInfo.buildNumber,
    );
  } else {
    final IosDeviceInfo info = await deviceInfo.iosInfo;
    return DeviceInfoPlus(
      emulator: !info.isPhysicalDevice,
      os: 'iOS',
      model: info.model,
      brand: 'Apple',
      uuid: info.identifierForVendor,
      osVersion: info.systemVersion,
      appVersion: packageInfo.version,
      appBuildNumber: packageInfo.buildNumber,
    );
  }
}

class DeviceInfoPlus {
  final String? model;
  final String? uuid;
  final bool emulator;
  final String? osVersion;
  final String os;
  final String? brand;
  final String? appVersion;
  final String? appBuildNumber;

  const DeviceInfoPlus({
    this.model,
    this.uuid,
    required this.emulator,
    required this.os,
    this.osVersion,
    this.brand,
    this.appVersion,
    this.appBuildNumber,
  });
}
