import 'dart:convert';

import 'package:http/http.dart' as http;

class WebhookService {
  WebhookService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> sendJson({
    required Uri uri,
    required Map<String, dynamic> body,
    String? secret,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'User-Agent': 'FuwariStudio',
    };
    if (secret != null && secret.trim().isNotEmpty) {
      headers['X-FuwariStudio-Secret'] = secret.trim();
    }

    final response = await _client
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Webhook HTTP ${response.statusCode}: ${response.body}');
    }
  }
}

