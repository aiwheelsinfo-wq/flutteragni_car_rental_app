import 'package:flutter_test/flutter_test.dart';
import 'package:agni_car_rental/utils/uber_map_markers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UberMapMarkers generates car and badge markers without error', () async {
    final car = await UberMapMarkers.getTopDownCarMarker();
    expect(car, isNotNull);
    final pickup = await UberMapMarkers.getPickupMarker();
    expect(pickup, isNotNull);
    final drop = await UberMapMarkers.getDropMarker();
    expect(drop, isNotNull);
  });
}
