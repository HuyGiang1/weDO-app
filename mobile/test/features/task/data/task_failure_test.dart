import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/task/data/task_failure.dart';

void main() {
  test('maps a validation failure to controlled Vietnamese feedback', () {
    expect(
      createTaskFailureMessage(
        const ApiException(code: 'VALIDATION_FAILED', statusCode: 400),
      ),
      'Thông tin công việc chưa hợp lệ. Kiểm tra tiêu đề và hạn hoàn thành.',
    );
  });

  test('maps inactive assignees and closed activity errors safely', () {
    expect(
      createTaskFailureMessage(
        const ApiException(code: 'GROUP_MEMBER_NOT_FOUND', statusCode: 404),
      ),
      'Người được giao không còn là thành viên hoạt động của nhóm.',
    );
    expect(
      createTaskFailureMessage(
        const ApiException(code: 'ACTIVITY_CLOSED', statusCode: 409),
      ),
      'Hoạt động hoặc nhóm không còn cho phép tạo công việc.',
    );
  });
}
