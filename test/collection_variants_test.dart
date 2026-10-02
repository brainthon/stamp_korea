import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stamp_korea/models/stamp.dart';
import 'package:stamp_korea/services/collection_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('same stamp variants persist and edit/delete independently', () async {
    SharedPreferences.setMockInitialValues({});
    await CollectionService.initialize();
    CollectionItem record(
      String id,
      StampCondition condition, [
      int count = 1,
    ]) => CollectionItem(
      id: id,
      stampId: 'epost_3834',
      condition: condition,
      count: count,
      acquiredDate: DateTime(2026),
    );
    await CollectionService.addOrUpdateItem(
      record('mint', StampCondition.mint),
    );
    await CollectionService.addOrUpdateItem(
      record('sheet', StampCondition.sheet),
    );
    await CollectionService.addOrUpdateItem(record('fdc', StampCondition.fdc));
    await CollectionService.addOrUpdateItem(
      record('mint2', StampCondition.mint),
    );
    await CollectionService.reloadForAccount();
    expect(CollectionService.getItemsByStampId('epost_3834').length, 4);
    await CollectionService.addOrUpdateItem(
      record('sheet', StampCondition.sheet, 3),
    );
    expect(CollectionService.countByStampId('epost_3834'), 6);
    expect(CollectionService.getStatistics()['uniqueCollected'], 1);
    await CollectionService.toggleWishlist('epost_3834');
    expect(CollectionService.getStatistics()['wishlistCount'], 1);
    await CollectionService.removeItem('fdc');
    await CollectionService.reloadForAccount();
    expect(CollectionService.getItemsByStampId('epost_3834').length, 3);
    expect(CollectionService.countByStampId('epost_3834'), 5);
    await CollectionService.toggleWishlist('epost_3834');
    expect(CollectionService.getStatistics()['wishlistCount'], 0);
  });
}
