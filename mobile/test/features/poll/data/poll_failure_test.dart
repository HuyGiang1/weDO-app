import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/poll/data/poll_failure.dart';

void main() {
  test('create failure maps validation errors to a controlled message', () {
    expect(
      createPollFailureMessage(const ApiException(code: 'VALIDATION_FAILED')),
      'Thông tin bình chọn chưa hợp lệ. Kiểm tra câu hỏi, lựa chọn và hạn bình chọn.',
    );
  });
}
