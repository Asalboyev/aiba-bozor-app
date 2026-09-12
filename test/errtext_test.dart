// errText — ekranga SINF NOMI emas, tushunarli matn chiqishi (QA 2026-09-08 regressiyasi).
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiba_pos_terminal/core/errors/failure.dart';
import 'package:aiba_pos_terminal/features/bozorkom/repo.dart';

void main() {
  const net = "Serverga ulanmadi — internetni tekshiring";
  test('NetworkFailure → tarmoq xabari', () {
    expect(BozorkomRepo.errText(const NetworkFailure(), net), net);
  });
  test('ServerFailure → server detail matni', () {
    expect(BozorkomRepo.errText(const ServerFailure("items bo'sh", statusCode: 400), net), "items bo'sh");
  });
  test('AuthFailure → o\'z matni, sinf nomi emas', () {
    final t = BozorkomRepo.errText(const AuthFailure('Invalid or expired token'), net);
    expect(t, 'Invalid or expired token');
    expect(t.contains('Failure'), isFalse);
  });
  test('DioException detail → detail', () {
    final ro = RequestOptions(path: '/x');
    final e = DioException(requestOptions: ro, response: Response(requestOptions: ro, statusCode: 400, data: {'detail': 'date majburiy'}));
    expect(BozorkomRepo.errText(e, net), 'date majburiy');
  });
  test('DioException javobsiz → tarmoq xabari', () {
    final e = DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError);
    expect(BozorkomRepo.errText(e, net), net);
  });
}
