import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:socket_io_client/socket_io_client.dart';

typedef void OnMessageCallback(dynamic msg);
typedef void OnCloseCallback(int code, String reason);
typedef void OnOpenCallback();
typedef void OnNewCallback(dynamic msg);
typedef void OnByeCallback(dynamic msg);
typedef void OnAnswerCallback(dynamic msg);
typedef void OnOfferCallback(dynamic msg);
typedef void OnLeaveCallback(dynamic msg);
typedef void OnKeepaliveCallback(dynamic msg);
typedef void OnCandidateCallback(dynamic msg);
typedef void OnUpdatePeersCallback(dynamic msg);
typedef void WhenCLose(dynamic msg);

class SimpleWebSocket {
  String? _url;
  IO.Socket? _socket;
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
    _socket = IO.io(
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
