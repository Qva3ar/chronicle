import 'dart:async';

class DataStream {
  final StreamController<int> _controller = StreamController<int>();

  Stream<int> get stream => _controller.stream;

  void updateData(int newData) {
    _controller.sink.add(newData);
    print('NEW DATA === $newData');
  }

  void dispose() {
    _controller.close();
  }
}