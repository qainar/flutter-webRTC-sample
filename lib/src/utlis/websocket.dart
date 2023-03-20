import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:socket_io_client/socket_io_client.dart';

typedef OnMessageCallback = void Function(dynamic msg);
typedef OnCloseCallback = void Function(int code, String reason);
typedef OnOpenCallback = void Function();
typedef OnNewCallback = void Function(dynamic msg);
typedef OnByeCallback = void Function(dynamic msg);
typedef OnAnswerCallback = void Function(dynamic msg);
typedef OnOfferCallback = void Function(dynamic msg);
typedef OnLeaveCallback = void Function(dynamic msg);
typedef OnKeepaliveCallback = void Function(dynamic msg);
typedef OnCandidateCallback = void Function(dynamic msg);
typedef OnUpdatePeersCallback = void Function(dynamic msg);
typedef WhenCLose = void Function(dynamic msg);

class SimpleWebSocket {
  final String? _url;
  io.Socket? _socket;
  OnOpenCallback? onOpen;
  OnMessageCallback? onMessage;
  OnCloseCallback? onClose;
  OnNewCallback? newCallback;
  OnByeCallback? byeCallback;
  OnAnswerCallback? answerCallback;
  OnOfferCallback? offerCallback;
  OnKeepaliveCallback? keepaliveCallback;
  OnLeaveCallback? leaveCallback;
  OnCandidateCallback? candidateCallback;
  OnUpdatePeersCallback? onUpdatePeers;
  WhenCLose? whenCLose;

  SimpleWebSocket(this._url);

  connect() {
    _socket = io.io(
        _url,
        OptionBuilder()
            .setTransports(['websocket']) // for Flutter or Dart VM
            .disableAutoConnect() // disable auto-connection
            .build());

    _socket?.connect();

    _socket?.onConnect((_) {
      print('connection success');
      onOpen!();
    });

    // _socket.on('message', (data) {
    //   print('$data ===================================================');
    //   this?.onMessage(data);
    // });

    _socket?.on('answer', (data) {
      answerCallback!(data);
    });
    _socket?.on('offer', (data) {
      offerCallback!(data);
    });
    _socket?.on('candidate', (data) {
      candidateCallback!(data);
    });
    _socket?.on('keepalive', (data) {
      keepaliveCallback!(data);
    });
    _socket?.on('bye', (data) {
      leaveCallback!(data);
    });
    _socket?.on('bye', (data) {
      byeCallback!(data);
    });
    _socket?.on('new', (data) {
      newCallback!(data);
    });

    _socket?.on('close', (data) => {whenCLose!(data)});
    // _socket.on('peers', (data) => {this.onUpdatePeers(data)});

    _socket?.onDisconnect((_) {
      onClose!(_socket!.connected ? 1000 : 1001, 'Disconnected');
    });

    _socket?.onError(
        (data) => {print('error -------------------------------- $data')});
  }

  send(ev, data) {
    if (_socket != null) {
      _socket?.emit(ev, data);
      print('send: $data');
    }
  }

  close() {
    _socket?.disconnect();
  }
}
