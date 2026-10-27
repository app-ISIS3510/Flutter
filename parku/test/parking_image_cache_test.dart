import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart' as files;
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/widgets/parking_photo.dart';

class TestImageFiles implements FileSystem {
  final String path;
  TestImageFiles(this.path);

  @override
  Future<files.File> createFile(String name) async {
    await io.Directory(path).create(recursive: true);
    return const LocalFileSystem().file('$path/$name');
  }
}

class UnavailableImageCache extends Fake implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool? withProgress,
  }) => Stream.error(const io.SocketException('Offline'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const url = 'https://parking.test/photo.png';
  late io.Directory directory;
  CacheManager? manager;
  late http.Client client;
  late Uint8List photo;
  var downloads = 0;
  var transferred = 0;
  var online = true;
  Completer<void>? responseGate;
  late Completer<void> received;

  CacheManager reopen() => CacheManager(
    Config(
      'parking_photo_test',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 30,
      repo: JsonCacheInfoRepository(path: '${directory.path}/metadata.json'),
      fileSystem: TestImageFiles('${directory.path}/images'),
      fileService: HttpFileService(httpClient: client),
    ),
  );

  CacheManager cache() => manager ??= reopen();

  setUp(() async {
    directory = await io.Directory.systemTemp.createTemp('parku-photo-cache-');
    photo = await io.File('assets/images/cityuimage.png').readAsBytes();
    downloads = 0;
    transferred = 0;
    online = true;
    responseGate = null;
    received = Completer<void>();
    client = MockClient((request) async {
      downloads++;
      if (!received.isCompleted) received.complete();
      if (!online) throw const io.SocketException('Offline');
      if (responseGate != null) await responseGate!.future;
      transferred += photo.length;
      return http.Response.bytes(
        photo,
        200,
        headers: {
          'content-type': 'image/png',
          'cache-control': 'max-age=86400',
        },
      );
    });
    manager = null;
  });

  tearDown(() async {
    await manager?.dispose();
    client.close();
    await directory.delete(recursive: true);
  });

  test('three visits reuse one image download instead of transferring it three times', () async {
    for (var i = 0; i < 3; i++) {
      await client.get(Uri.parse(url));
    }
    expect(downloads, 3);
    final withoutCache = transferred;
    downloads = 0;
    transferred = 0;

    for (var i = 0; i < 3; i++) {
      final file = await cache().getSingleFile(url);
      expect(await file.readAsBytes(), photo);
    }
    expect(downloads, 1);
    expect(transferred * 3, withoutCache);
  });

  test(
    'disk caching still returns the downloaded image after reopening offline',
    () async {
      final first = await cache().getSingleFile(url);
      await cache().dispose();
      manager = reopen();
      online = false;

      final saved = await cache().getSingleFile(url);

      expect(saved.path, first.path);
      expect(await saved.readAsBytes(), photo);
      expect(downloads, 1);
    },
  );

  test(
    'an expired image stays visible when refreshing it fails offline',
    () async {
      await cache().putFile(url, photo, maxAge: const Duration(seconds: -1));
      online = false;

      final results = await cache()
          .getFileStream(url)
          .where((file) => file is FileInfo)
          .toList();

      expect(results, hasLength(1));
      final saved = results.single as FileInfo;
      expect(saved.source, FileSource.Cache);
      expect(await saved.file.readAsBytes(), photo);
      expect(downloads, 1);
    },
  );

  test(
    'simultaneous requests for the same image share a single download',
    () async {
      responseGate = Completer<void>();
      final requests = Future.wait([
        cache().getSingleFile(url),
        cache().getSingleFile(url),
        cache().getSingleFile(url),
      ]);
      await received.future;
      expect(downloads, 1);
      responseGate!.complete();
      final images = await requests;
      expect(images.map((image) => image.path).toSet(), hasLength(1));
      expect(downloads, 1);
    },
  );

  testWidgets(
    'a failed image uses the original photo without changing the layout',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingPhoto(
              imageUrl: url,
              cacheManager: UnavailableImageCache(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(ParkingPhoto)).height, 150);
      final image = tester.widget<Image>(find.byType(Image).last);
      expect(image.image, isA<AssetImage>());
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/cityuimage.png',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the default photo has a stable cache URL and custom URLs are supported',
    (tester) async {
      final cache = UnavailableImageCache();
      await tester.pumpWidget(
        MaterialApp(home: ParkingPhoto(cacheManager: cache)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
            .imageUrl,
        ParkingPhoto.defaultUrl,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ParkingPhoto(imageUrl: url, cacheManager: cache),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
            .imageUrl,
        url,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('optional image URLs survive saving parking data without changing old records', () {
    final row = {'id': 'parking-1', 'name': 'City U', 'address': 'Calle 20'};
    final old = Parking.fromMap(row);
    expect(old.imageUrl, isNull);
    final parking = Parking.fromMap({...row, 'image_url': url});
    expect(Parking.fromMap(parking.toMap()).imageUrl, url);
  });
}
