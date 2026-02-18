import 'package:fero_sync/core/exceptions.dart';

void main() {
  final e = MaxRetriesExceededException('test');
  print('Is Exception: ${e is Exception}');
  print('Type: ${e.runtimeType}');
  print('ToString: ${e.toString()}');
}
