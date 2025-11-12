import 'package:flutter_test/flutter_test.dart';
import '../lib/curl_parser.dart';

void main() {
  group('CurlParser', () {
    late CurlParser parser;

    setUp(() {
      parser = CurlParser();
    });

    group('Basic URL extraction', () {
      test('parses simple GET request', () async {
        const command = 'curl https://jsonplaceholder.typicode.com/posts/1';
        final request = await parser.parse(command);

        expect(request.url.toString(), 'https://jsonplaceholder.typicode.com/posts/1');
        expect(request.method, 'GET');
      });

      test('parses GET request with -X flag', () async {
        const command = 'curl -X GET https://jsonplaceholder.typicode.com/posts/1';
        final request = await parser.parse(command);

        expect(request.url.toString(), 'https://jsonplaceholder.typicode.com/posts/1');
        expect(request.method, 'GET');
      });

      test('parses POST request', () async {
        const command = 'curl -X POST https://jsonplaceholder.typicode.com/posts';
        final request = await parser.parse(command);

        expect(request.url.toString(), 'https://jsonplaceholder.typicode.com/posts');
        expect(request.method, 'POST');
      });

      test('parses URL with --location flag', () async {
        const command = "curl --location 'https://api.example.com/endpoint'";
        final request = await parser.parse(command);

        expect(request.url.toString(), 'https://api.example.com/endpoint');
        expect(request.method, 'GET');
      });
    });

    group('Header parsing', () {
      test('parses single header with -H flag', () async {
        const command = "curl -H 'X-Custom-Header: custom-value' https://api.example.com";
        final request = await parser.parse(command);

        expect(request.headers['X-Custom-Header'], 'custom-value');
      });

      test('parses single header with --header flag', () async {
        const command = "curl --header 'Authorization: Bearer TOKEN' https://api.example.com";
        final request = await parser.parse(command);

        expect(request.headers['Authorization'], 'Bearer TOKEN');
      });

      test('parses X-Device-Source header correctly', () async {
        const command = "curl --header 'X-Device-Source: 4' https://api.example.com";
        final request = await parser.parse(command);

        expect(request.headers['X-Device-Source'], '4');
      });

      test('parses multiple headers', () async {
        const command = """curl https://api.example.com \\
          -H 'X-Device-Source: 4' \\
          -H 'Authorization: Bearer TOKEN' \\
          -H 'X-Device-Version: 8.74'""";
        final request = await parser.parse(command);

        expect(request.headers['X-Device-Source'], '4');
        expect(request.headers['Authorization'], 'Bearer TOKEN');
        expect(request.headers['X-Device-Version'], '8.74');
      });

      test('parses header values containing colons', () async {
        const command = "curl -H 'Location: https://example.com:8080/path' https://api.example.com";
        final request = await parser.parse(command);

        expect(request.headers['Location'], 'https://example.com:8080/path');
      });
    });

    group('Multi-line curl commands', () {
      test('parses multi-line curl with backslash continuations', () async {
        const command = """curl --location 'http://api.talabat.com/home/v2/ae/content?lat=25.18826954019318&lon=55.258512212709654&area_id=1170&country_id=4' \\
--header 'X-Device-Source: 4' \\
--header 'Authorization: Bearer TOKEN' \\
--header 'X-Device-Version: 8.74'""";
        final request = await parser.parse(command);

        expect(
          request.url.toString(),
          'http://api.talabat.com/home/v2/ae/content?lat=25.18826954019318&lon=55.258512212709654&area_id=1170&country_id=4',
        );
        expect(request.headers['X-Device-Source'], '4');
        expect(request.headers['Authorization'], 'Bearer TOKEN');
        expect(request.headers['X-Device-Version'], '8.74');
        expect(request.method, 'GET');
      });

      test('handles Windows-style line breaks', () async {
        const command = "curl --location 'https://api.example.com' \\\r\n--header 'X-Custom: value'";
        final request = await parser.parse(command);

        expect(request.url.toString(), 'https://api.example.com');
        expect(request.headers['X-Custom'], 'value');
      });
    });

    group('Request body parsing', () {
      test('parses request body with -d flag', () async {
        const command = "curl -X POST -d '{\"key\":\"value\"}' https://api.example.com";
        final request = await parser.parse(command);

        expect(request.body, '{"key":"value"}');
        expect(request.method, 'POST');
      });

      test('parses request body with --data flag', () async {
        const command = "curl --data 'name=John&age=30' https://api.example.com";
        final request = await parser.parse(command);

        expect(request.body, 'name=John&age=30');
      });

      test('parses request body with --data-raw flag', () async {
        const command = "curl --data-raw '{\"user\":\"test\"}' https://api.example.com";
        final request = await parser.parse(command);

        expect(request.body, '{"user":"test"}');
      });
    });

    group('Complex real-world examples', () {
      test('parses Talabat API request with query parameters', () async {
        const command = """curl --location 'http://api.talabat.com/home/v2/ae/content?lat=25.18826954019318&lon=55.258512212709654&area_id=1170&country_id=4' \\
--header 'X-Device-Source: 4' \\
--header 'Authorization: Bearer TOKEN' \\
--header 'X-Device-Version: 8.74'""";
        final request = await parser.parse(command);

        expect(request.method, 'GET');
        expect(request.url.scheme, 'http');
        expect(request.url.host, 'api.talabat.com');
        expect(request.url.path, '/home/v2/ae/content');
        expect(request.url.queryParameters['lat'], '25.18826954019318');
        expect(request.url.queryParameters['lon'], '55.258512212709654');
        expect(request.url.queryParameters['area_id'], '1170');
        expect(request.url.queryParameters['country_id'], '4');
        expect(request.headers['X-Device-Source'], '4');
        expect(request.headers['Authorization'], 'Bearer TOKEN');
        expect(request.headers['X-Device-Version'], '8.74');
      });

      test('parses exact failing Talabat API curl command', () async {
        const command = """curl --location 'http://api.talabat.com/home/v2/ae/content?lat=25.18826954019318&lon=55.258512212709654&area_id=1170&country_id=4' \\
--header 'X-Device-Version: 8.74' \\
--header 'Authorization: TOKEN' \\
--header 'X-Device-Source: 4'""";
        final request = await parser.parse(command);

        expect(request.method, 'GET');
        expect(request.url.toString(), 'http://api.talabat.com/home/v2/ae/content?lat=25.18826954019318&lon=55.258512212709654&area_id=1170&country_id=4');
        expect(request.headers['X-Device-Version'], '8.74');
        expect(request.headers['Authorization'], 'TOKEN');
        expect(request.headers['X-Device-Source'], '4');
      });

      test('parses curl with REAL newlines (as pasted in text field)', () async {
        // This simulates what happens when you paste a multi-line curl command
        // Note: The triple-quote string preserves actual newline characters
        final command = '''curl --location 'http://api.talabat.com/home/v2/ae/content?lat=25.18826954019318&lon=55.258512212709654&area_id=1170&country_id=4' \\
--header 'X-Device-Version: 8.74' \\
--header 'Authorization: TOKEN' \\
--header 'X-Device-Source: 4' ''';

        final request = await parser.parse(command);

        expect(request.method, 'GET');
        expect(request.url.toString(), 'http://api.talabat.com/home/v2/ae/content?lat=25.18826954019318&lon=55.258512212709654&area_id=1170&country_id=4');
        expect(request.headers['X-Device-Version'], '8.74');
        expect(request.headers['Authorization'], 'TOKEN');
        expect(request.headers['X-Device-Source'], '4');
      });

      test('parses POST request with headers and body', () async {
        const command = """curl -X POST https://api.example.com/users \\
-H 'Content-Type: application/json' \\
-H 'X-Device-Source: 4' \\
-d '{"name":"John Doe","email":"john@example.com"}'""";
        final request = await parser.parse(command);

        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://api.example.com/users');
        // Note: http.Request automatically adds charset=utf-8 to Content-Type
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(request.headers['X-Device-Source'], '4');
        expect(request.body, '{"name":"John Doe","email":"john@example.com"}');
      });
    });

    group('Quote handling', () {
      test('handles single-quoted strings', () async {
        const command = "curl 'https://api.example.com' -H 'X-Custom: value'";
        final request = await parser.parse(command);

        expect(request.url.toString(), 'https://api.example.com');
        expect(request.headers['X-Custom'], 'value');
      });

      test('handles double-quoted strings', () async {
        const command = 'curl "https://api.example.com" -H "X-Custom: value"';
        final request = await parser.parse(command);

        expect(request.url.toString(), 'https://api.example.com');
        expect(request.headers['X-Custom'], 'value');
      });

      test('handles mixed quotes', () async {
        const command = '''curl 'https://api.example.com' -H "X-Custom: value"''';
        final request = await parser.parse(command);

        expect(request.url.toString(), 'https://api.example.com');
        expect(request.headers['X-Custom'], 'value');
      });
    });

    group('Edge cases and error handling', () {
      test('throws error when URL is missing', () async {
        const command = 'curl -H "X-Custom: value"';

        expect(
          () async => await parser.parse(command),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Invalid cURL command: URL not found.',
          )),
        );
      });

      test('handles empty command', () async {
        const command = '';

        expect(
          () async => await parser.parse(command),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('handles command with only curl keyword', () async {
        const command = 'curl';

        expect(
          () async => await parser.parse(command),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('handles extra whitespace', () async {
        const command = '  curl    https://api.example.com   -H   "X-Custom: value"  ';
        final request = await parser.parse(command);

        expect(request.url.toString(), 'https://api.example.com');
        expect(request.headers['X-Custom'], 'value');
      });
    });

    group('HTTP method variations', () {
      test('normalizes method to uppercase', () async {
        const command = 'curl -X post https://api.example.com';
        final request = await parser.parse(command);

        expect(request.method, 'POST');
      });

      test('handles PUT method', () async {
        const command = 'curl -X PUT https://api.example.com/resource/1';
        final request = await parser.parse(command);

        expect(request.method, 'PUT');
      });

      test('handles DELETE method', () async {
        const command = 'curl -X DELETE https://api.example.com/resource/1';
        final request = await parser.parse(command);

        expect(request.method, 'DELETE');
      });

      test('handles PATCH method', () async {
        const command = 'curl --request PATCH https://api.example.com/resource/1';
        final request = await parser.parse(command);

        expect(request.method, 'PATCH');
      });
    });
  });
}