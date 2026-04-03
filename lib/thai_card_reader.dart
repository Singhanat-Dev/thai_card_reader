import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:flutter/services.dart';

import 'src/card_data.dart';
import 'src/card_read_result.dart';

export 'src/card_data.dart';
export 'src/card_read_result.dart';

class ThaiCardReader {
  // ── Singleton ──
  static final ThaiCardReader instance = ThaiCardReader._();
  ThaiCardReader._() {
    _initMessageChannel();
  }

  // ── Channels ──
  static const _methodChannel = MethodChannel('NiosLib/Api');
  static const _messageChannel = BasicMessageChannel<String>('NiosLib/message', StringCodec());
  static const _eventChannel = EventChannel('NiosLib/usb_events');

  // ── Card events stream (from BasicMessageChannel) ──
  final _cardEventsController = StreamController<Map<String, dynamic>>.broadcast();

  void _initMessageChannel() {
    _messageChannel.setMessageHandler((String? message) async {
      if (message == null) return '';
      try {
        final json = jsonDecode(message) as Map<String, dynamic>;
        _cardEventsController.add(json);
      } catch (_) {}
      return '';
    });
  }

  /// Stream of card reading events (from BasicMessageChannel).
  /// Each event is a Map with keys: 'ResCode', 'ResValue', optionally 'ResText', 'ResPhoto', 'ResPhotoSize'.
  Stream<Map<String, dynamic>> get cardEvents => _cardEventsController.stream;

  /// Stream of USB hardware events (from EventChannel, Android only).
  /// Events: device_attached, device_detached, permission_granted, permission_denied, readers_found, reader_not_found.
  /// Returns an empty stream on iOS (BLE mode has no USB events).
  Stream<Map<String, dynamic>> get usbEvents {
    if (Platform.isIOS) return const Stream.empty();
    return _eventChannel.receiveBroadcastStream().map((dynamic event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{'event': event.toString()};
    });
  }

  /// Reader type: Android=7 (USB+BT+BLE), iOS=4 (BLE only).
  int get readerType => Platform.isAndroid ? 7 : 4;

  /// License file path: Android='rdnidlib.dls', iOS='' (BLE mode needs no file).
  String get licensePath => Platform.isAndroid ? 'rdnidlib.dls' : '';

  // ── Public API ──

  /// Open the NID library. Returns null on success, error string on failure.
  /// Handles ResCode -12 (license expired) by calling updateLicenseFileNi automatically.
  Future<String?> openLib() async {
    // Set reader type first
    await invoke('setReaderType', {'readerType': readerType.toString()});

    final result = await invoke('openNiOSLibNi', {'path': licensePath});
    if (isSuccess(result)) return null;

    final code = result?['ResCode'];
    // -12 = license expired: attempt update
    if (code == -12 || code == '-12') {
      final updateResult = await invoke('updateLicenseFileNi');
      if (isSuccess(updateResult)) {
        // Retry open after update
        final retryResult = await invoke('openNiOSLibNi', {'path': licensePath});
        if (isSuccess(retryResult)) return null;
        return retryResult?['ResValue']?.toString() ?? 'Failed to open library after license update';
      }
      return updateResult?['ResValue']?.toString() ?? 'License update failed';
    }

    return result?['ResValue']?.toString() ?? 'Failed to open library';
  }

  /// Close the library (deselectReader + closeLib).
  Future<void> closeLib() async {
    await invoke('deselectReaderNi');
    await invoke('closeNiOSLibNi');
  }

  /// Scan for readers and return raw JSON response.
  /// On Android: calls getReaderListNi (shows popup).
  /// On iOS: calls scanReaderListBleNi with [bleTimeout] seconds (default 10).
  /// ResCode from native = number of readers found (>0 = success).
  /// Normalized to ResCode:0 so callers can use [isSuccess] uniformly.
  Future<Map<String, dynamic>?> scanReaders({int bleTimeout = 10}) async {
    final result = await (Platform.isAndroid
        ? invoke('getReaderListNi')
        : invoke('scanReaderListBleNi', {'timeout': bleTimeout}));
    if (result == null) return null;
    final code = result['ResCode'];
    final n = code is int ? code : int.tryParse(code.toString()) ?? -1;
    if (n > 0) return {...result, 'ResCode': 0};
    return result;
  }

  /// Select a reader by name. Returns null on success, error string on failure.
  Future<String?> selectReader(String name) async {
    final result = await invoke('selectReaderNi', {'reader': name});
    if (isSuccess(result)) return null;
    return result?['ResValue']?.toString() ?? 'Failed to select reader';
  }

  /// Read all card data. Returns CardReadResult.
  Future<CardReadResult> readCard() async {
    final result = await invoke('readAllData');
    if (result == null) {
      return const CardReadResult.failure('No response from native');
    }
    if (!isSuccess(result)) {
      final errVal = result['ResValue']?.toString() ?? 'Read failed';
      return CardReadResult.failure(errVal);
    }

    final resText = result['ResText']?.toString() ?? '';
    final resPhoto = result['ResPhoto']?.toString() ?? '';
    final resPhotoSize = int.tryParse(result['ResPhotoSize']?.toString() ?? '0') ?? 0;

    if (resText.isEmpty) {
      return const CardReadResult.failure('No card text data returned');
    }

    try {
      final cardData = CardData.parse(resText, resPhoto, resPhotoSize);
      return CardReadResult.success(cardData);
    } catch (e) {
      return CardReadResult.failure('Parse error: $e');
    }
  }

  /// Get list of connected USB smart card readers.
  Future<List<Map<String, dynamic>>> getConnectedReaders() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getConnectedReaders');
      if (result == null) return [];
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on PlatformException {
      return [];
    }
  }

  /// Get reader info.
  Future<Map<String, dynamic>?> getReaderInfo() => invoke('getReaderInfoNi');

  /// Get software version info.
  Future<Map<String, dynamic>?> getSoftwareInfo() => invoke('getSoftwareInfoNi');

  /// Get license info.
  Future<Map<String, dynamic>?> getLicenseInfo() => invoke('getLicenseInfoNi');

  /// Low-level: invoke any method channel call.
  Future<Map<String, dynamic>?> invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      final res = await _methodChannel.invokeMethod<String>(method, args);
      if (res == null) return null;
      final json = jsonDecode(res) as Map<String, dynamic>;
      log('$method: → $json', name: 'ThaiCardReader');
      return json;
    } on PlatformException {
      return null;
    }
  }

  /// Returns true if the JSON response indicates success (ResCode == 0).
  bool isSuccess(Map<String, dynamic>? json) {
    final code = json?['ResCode'];
    return code == 0 || code == '0';
  }
}
