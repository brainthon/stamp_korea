import 'dart:async';
import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void mockCatalogImages() {
  final bytes = File('assets/branding/app-logo.png').readAsBytesSync();
  debugNetworkImageHttpClientProvider = () => _Client(bytes);
}

void catalogTestWidgets(String name, WidgetTesterCallback callback) {
  testWidgets(name, (tester) async {
    mockCatalogImages();
    try {
      await callback(tester);
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  });
}

class _Client implements HttpClient {
  _Client(this.bytes);
  final List<int> bytes;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.bytes);
  final List<int> bytes;
  @override
  Future<HttpClientResponse> close() async => _Response(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends StreamView<List<int>> implements HttpClientResponse {
  _Response(this.bytes) : super(Stream.value(bytes));
  final List<int> bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
