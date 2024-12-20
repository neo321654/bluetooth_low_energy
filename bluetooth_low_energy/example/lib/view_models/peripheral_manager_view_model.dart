import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:bluetooth_low_energy_example/models.dart';
import 'package:clover/clover.dart';
import 'package:logging/logging.dart';

class PeripheralManagerViewModel extends ViewModel {
  final PeripheralManager _manager;
  final List<Log> _logs;
  bool _advertising;

  int answerValue = 22;

  late final StreamSubscription _stateChangedSubscription;
  late final StreamSubscription _characteristicReadRequestedSubscription;
  late final StreamSubscription _characteristicWriteRequestedSubscription;
  late final StreamSubscription _characteristicNotifyStateChangedSubscription;
  // late final Stream streamWriteValues;

  PeripheralManagerViewModel()
      : _manager = PeripheralManager()..logLevel = Level.INFO,


        _logs = [],
        _advertising = false {




    _stateChangedSubscription = _manager.stateChanged.listen((eventArgs) async {
      if (eventArgs.state == BluetoothLowEnergyState.unauthorized &&
          Platform.isAndroid) {
        await _manager.authorize();
      }
      notifyListeners();
    });
    // streamWriteValues =  _manager.characteristicWriteRequested;
    _characteristicReadRequestedSubscription =
        _manager.characteristicReadRequested.listen((eventArgs) async {
      final central = eventArgs.central;
      final characteristic = eventArgs.characteristic;
      final request = eventArgs.request;
      final offset = request.offset;
      final log = Log(
        type: 'Characteristic read requested',
        message: '${central.uuid}, ${characteristic.uuid}, $offset',
      );
      _logs.add(log);
      notifyListeners();
      final elements = List.generate(100, (i) => i % 256);
      // final value = Uint8List.fromList(elements);
      // final value = Uint8List.fromList([DateTime.now().millisecondsSinceEpoch]);
      final value = Uint8List.fromList([answerValue]);
      final trimmedValue = value.sublist(offset);
      await _manager.respondReadRequestWithValue(
        request,
        value: trimmedValue,
      );
    });
    _characteristicWriteRequestedSubscription =
        _manager.characteristicWriteRequested.listen((eventArgs) async {
      final central = eventArgs.central;
      final characteristic = eventArgs.characteristic;
      final request = eventArgs.request;
      final offset = request.offset;
      final value = request.value;
      final log = Log(
        type: 'Characteristic write requested',
        message:
            '${String.fromCharCodes(value)}',
            // '[${String.fromCharCodes(value)}]',
            // '[${value.length}] ${central.uuid}, ${characteristic.uuid}, $offset, $value = ${String.fromCharCodes(value)}',
      );
      _logs.add(log);
      notifyListeners();
      await _manager.respondWriteRequest(request);
    });
    _characteristicNotifyStateChangedSubscription =
        _manager.characteristicNotifyStateChanged.listen((eventArgs) async {
      final central = eventArgs.central;
      final characteristic = eventArgs.characteristic;
      final state = eventArgs.state;
      final log = Log(
        type: 'Characteristic notify state changed',
        message: '${central.uuid}, ${characteristic.uuid}, $state',
      );
      _logs.add(log);
      notifyListeners();
      // Write someting to the central when notify started.
      if (state) {
        final maximumNotifyLength =
            await _manager.getMaximumNotifyLength(central);
        final elements = List.generate(maximumNotifyLength, (i) => i % 256);
        final value = Uint8List.fromList(elements);
        await _manager.notifyCharacteristic(
          central,
          characteristic,
          value: value,
        );
      }
    });
  }

  BluetoothLowEnergyState get state => _manager.state;
  bool get advertising => _advertising;
  List<Log> get logs => _logs;

  Future<void> showAppSettings() async {
    await _manager.showAppSettings();
  }

  Future<void> startAdvertising() async {
    if (_advertising) {
      return;
    }
    await _manager.removeAllServices();
    final elements = List.generate(100, (i) => i % 256);
    // final value = Uint8List.fromList(elements);
    final value = Uint8List.fromList([answerValue]);
    final service = GATTService(
      uuid: UUID.short(100),
      isPrimary: true,
      includedServices: [],
      characteristics: [
        GATTCharacteristic.immutable(
          uuid: UUID.short(200),
          value: value,
          descriptors: [],
        ),
        GATTCharacteristic.mutable(
          uuid: UUID.short(201),
          properties: [
            GATTCharacteristicProperty.read,
            GATTCharacteristicProperty.write,
            GATTCharacteristicProperty.writeWithoutResponse,
            GATTCharacteristicProperty.notify,
            GATTCharacteristicProperty.indicate,
          ],
          permissions: [
            GATTCharacteristicPermission.read,
            GATTCharacteristicPermission.write,
          ],
          descriptors: [],
        ),
      ],
    );
    await _manager.addService(service);
    final advertisement = Advertisement(
      name: Platform.isWindows ? null : 'BLE-12138',
      manufacturerSpecificData: Platform.isIOS || Platform.isMacOS
          ? []
          : [
              ManufacturerSpecificData(
                id: 0x2e19,
                data: Uint8List.fromList([0x01, 0x02, 0x03]),
              )
            ],
    );
    await _manager.startAdvertising(advertisement);
    _advertising = true;
    notifyListeners();
  }

  Future<void> stopAdvertising() async {
    if (!_advertising) {
      return;
    }
    await _manager.stopAdvertising();
    _advertising = false;
    notifyListeners();
  }

  Future<void> setNewValue() async {
    if (!_advertising) {
      return;
    }
    // await _manager.stopAdvertising();
    // _advertising = false;
    answerValue++;
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _stateChangedSubscription.cancel();
    _characteristicReadRequestedSubscription.cancel();
    _characteristicWriteRequestedSubscription.cancel();
    _characteristicNotifyStateChangedSubscription.cancel();
    super.dispose();
  }
}
