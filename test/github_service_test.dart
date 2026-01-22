import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:fuwari_studio/services/github_service.dart';

class FailingClient extends http.BaseClient {
  FailingClient(this.error);

  final Object error;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Future<http.StreamedResponse>.error(error);
  }
}

void main() {
  test('fetchRepoInfo wraps network failures', () async {
    final service = GitHubService(
      client: FailingClient(
        http.ClientException(
          "SocketException: Failed host lookup: 'api.github.com'",
        ),
      ),
    );

    expect(
      () => service.fetchRepoInfo(owner: 'o', repo: 'r'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Network error while calling GitHub API'),
        ),
      ),
    );
  });
}

