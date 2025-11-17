import 'package:http/http.dart' as http;

class CurlParser {
  Future<http.Request> parse(String curlCommand) async {
    // Normalize line continuations (backslash + newline)
    // Handle both actual newlines and escaped newlines
    var normalized = curlCommand
        // Handle backslash followed by actual newline (when pasted from curl)
        .replaceAll(RegExp(r'\\\r?\n'), ' ')
        // Handle just newlines without backslash
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        // Collapse multiple spaces into one
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final parts = _splitCommand(normalized);
    final url = _extractUrl(parts);

    if (url.isEmpty) {
      throw ArgumentError('Invalid cURL command: URL not found.');
    }

    final method = _extractMethod(parts);
    final headers = _extractHeaders(parts);
    final body = _extractBody(parts);

    final request = http.Request(method, Uri.parse(url));
    request.headers.addAll(headers);
    request.body = body;

    return request;
  }

  /// Split command respecting quoted strings
  List<String> _splitCommand(String command) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    var quoteChar = '';

    for (int i = 0; i < command.length; i++) {
      final char = command[i];

      if ((char == '"' || char == "'") && (i == 0 || command[i - 1] != '\\')) {
        if (!inQuotes) {
          inQuotes = true;
          quoteChar = char;
        } else if (char == quoteChar) {
          inQuotes = false;
          quoteChar = '';
        } else {
          buffer.write(char);
        }
      } else if (char == ' ' && !inQuotes) {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }

    return parts;
  }

  String _extractUrl(List<String> parts) {
    // Skip 'curl' if it's the first part
    final searchParts = parts.where((part) => part.toLowerCase() != 'curl').toList();

    // Look for URL after --location or -L
    for (int i = 0; i < searchParts.length; i++) {
      if (searchParts[i] == '--location' || searchParts[i] == '-L') {
        if (i + 1 < searchParts.length && _isUrl(searchParts[i + 1])) {
          return searchParts[i + 1];
        }
      }
    }

    // Look for URL after --url
    for (int i = 0; i < searchParts.length; i++) {
      if (searchParts[i] == '--url') {
        if (i + 1 < searchParts.length && _isUrl(searchParts[i + 1])) {
          return searchParts[i + 1];
        }
      }
    }

    // Fallback: find first http/https URL that's not a flag argument
    for (int i = 0; i < searchParts.length; i++) {
      final part = searchParts[i];
      if (_isUrl(part) && !part.startsWith('-')) {
        return part;
      }
    }

    return '';
  }

  bool _isUrl(String part) {
    return part.startsWith('http://') || part.startsWith('https://');
  }

  String _extractMethod(List<String> parts) {
    for (int i = 0; i < parts.length; i++) {
      if (parts[i] == '-X' || parts[i] == '--request') {
        if (i + 1 < parts.length) {
          return parts[i + 1].toUpperCase();
        }
      }
    }
    return 'GET';
  }

  Map<String, String> _extractHeaders(List<String> parts) {
    final headers = <String, String>{};
    for (int i = 0; i < parts.length; i++) {
      if ((parts[i] == '-H' || parts[i] == '--header') && i + 1 < parts.length) {
        final header = parts[i + 1];
        // Split only on first colon to handle values with colons
        final colonIndex = header.indexOf(':');
        if (colonIndex > 0) {
          final key = header.substring(0, colonIndex).trim();
          final value = header.substring(colonIndex + 1).trim();
          headers[key] = value;
        }
      }
    }
    return headers;
  }

  String _extractBody(List<String> parts) {
    for (int i = 0; i < parts.length; i++) {
      if ((parts[i] == '-d' || parts[i] == '--data' || parts[i] == '--data-raw') && i + 1 < parts.length) {
        return parts[i + 1];
      }
    }
    return '';
  }
}
