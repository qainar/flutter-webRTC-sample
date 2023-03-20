import 'dart:convert';
import 'dart:async';
import 'dart:developer';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'random_strings.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:socket_io_client/socket_io_client.dart';

import '../utlis/device_info.dart';
import '../utlis/websocket.dart';

enum SignalingState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

enum VideoSource {
  Camera,
  Screen,
}

/*
 * callbacks for Signaling API.
 */
typedef void SignalingStateCallback(SignalingState state);
typedef void StreamStateCallback(MediaStream stream);
typedef void OtherEventCallback(dynamic event);
typedef void DataChannelMessageCallback(
    RTCDataChannel dc, RTCDataChannelMessage data);
typedef void DataChannelCallback(RTCDataChannel dc);

class Signaling {
  String _selfId = randomNumeric(6);
  SimpleWebSocket? _socket;
  IO.Socket? socket;
  late String _sessionId;
  late String _host;
  int _port = 6930;
  late final Map<String, RTCPeerConnection> _peerConnections =
      Map<String, RTCPeerConnection>();
  late Map<String, RTCDataChannel> _dataChannels =
      Map<String, RTCDataChannel>();
  late List<RTCIceCandidate> _remoteCandidates = [];
  List<RTCRtpSender> _senders = <RTCRtpSender>[];
  VideoSource _videoSource = VideoSource.Camera;

  Map<String, dynamic>? mapData;

  JsonDecoder decoder = JsonDecoder();
  late String _id;
  late String _media;
  late String _description;
  late Map<String, dynamic> type;

  MediaStream? _localStream;
  var lol;
  List<MediaStream>? _remoteStreams;
  SignalingStateCallback? onStateChange;
  StreamStateCallback? onLocalStream;
  StreamStateCallback? onAddRemoteStream;
  StreamStateCallback? onRemoveRemoteStream;
  OtherEventCallback? onPeersUpdate;
  DataChannelMessageCallback? onDataChannelMessage;
  DataChannelCallback? onDataChannel;

  Map<String, dynamic> _iceServers = {
    'sdpSemantics': 'plan-b',
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      /*
       * turn server configuration example.
      {
        'url': 'turn:123.45.67.89:3478',
        'username': 'change_to_real_user',
        'credential': 'change_to_real_secret'
      },
       */
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  final Map<String, dynamic> _dc_constraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

  Signaling(this._host);

  close() {
    if (_localStream != null) {
      _localStream?.dispose();
      _localStream = null;
    }

    _peerConnections.forEach((key, pc) {
      pc.close();
    });
    if (_socket != null) _socket?.close();
  }

  Future<void> switchCamera() async {
    print('camera switched');
    print('$_senders senders');
    if (_videoSource != VideoSource.Camera) {
      _senders.forEach((sender) {
        if (sender.track!.kind == 'video') {
          sender.replaceTrack(_localStream!.getVideoTracks()[0]);
        }
      });
      _videoSource = VideoSource.Camera;
      onLocalStream!.call(_localStream!);
    } else {
      Helper.switchCamera(_localStream!.getVideoTracks()[0]);
    }
  }

  Future<void> muteMic() async {
    if (_localStream != null) {
      bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
    }
  }

  void whenclose() {
    log('@@@@ =============================');
    _send('close', {
      'session_id': _sessionId,
    });
  }

  void invite(String peer_id, String media, use_screen) {
    _sessionId = '${_selfId}-$peer_id';

    if (onStateChange != null) {
      onStateChange!(SignalingState.CallStateNew);
    }

    _createPeerConnection(peer_id, media, use_screen).then((pc) {
      _peerConnections[peer_id] = pc;
      if (media == 'video') {
        _createDataChannel(peer_id, pc);
      }
      _createOffer(peer_id, pc, media);
    });
  }

  void bye() {
    _send('bye', {
      'session_id': _sessionId,
      'from': _selfId,
    });
  }

  void connect() async {
    var url = 'wss://$_host:$_port';
    _socket = SimpleWebSocket(url);

    print('connect to $url');
    _socket?.onOpen = () {
      print('onOpen');
      onStateChange!(SignalingState.ConnectionOpen);
      var data = {
        'name': DeviceInfo.label,
        'id': _selfId,
        'user_agent': DeviceInfo.userAgent
      };

      _send('new', data);
    };

    _socket?.whenCLose = (message) {
      mapData = decoder.convert(message);
      type = decoder.convert(message);
      inspect(type);
      if (type['type'] == 'close') {
        var data = mapData!['data'];
        // var sessionId = data['session_id'];

        log('$message =============================');
        if (_localStream != null) {
          _localStream?.dispose();
          _localStream = null;
        }
        _senders.clear();
        _videoSource = VideoSource.Camera;

        _peerConnections.forEach((key, pc) {
          pc.close();
        });
      }
    };

    _socket?.newCallback = (message) {
      type = decoder.convert(message);
      if (type['type'] == 'peers') {
        print('new callback');
        mapData = decoder.convert(message);
        var data = mapData!['data'];
        List<dynamic> peers = data;
        if (onPeersUpdate != null) {
          Map<String, dynamic> event = Map<String, dynamic>();
          event['self'] = _selfId;
          event['peers'] = peers;
          onPeersUpdate!(event);
        }
      }
    };
    _socket?.offerCallback = (message) async {
      var type = decoder.convert(message);

      if (type['type'] == 'offer') {
        mapData = decoder.convert(message);
        var data = mapData!['data'];
        var id = data['from'];
        var description = data['description'];
        var media = data['media'];
        var sessionId = data['session_id'];
        _sessionId = sessionId;
        if (onStateChange != null) {
          onStateChange!(SignalingState.CallStateNew);
        }

        var pc = await _createPeerConnection(id, media, false);
        _peerConnections[id] = pc;
        await pc.setRemoteDescription(
            RTCSessionDescription(description['sdp'], description['type']));
        await _createAnswer(id, pc, media);
        if (_remoteCandidates.length > 0) {
          _remoteCandidates.forEach((candidate) async {
            await pc.addCandidate(candidate);
          });
          _remoteCandidates.clear();
        }
      }
    };

    _socket?.answerCallback = (message) async {
      var type = decoder.convert(message);

      if (type['type'] == 'answer') {
        // JsonDecoder decoder = new JsonDecoder();
        // Map<String, dynamic> mapData = decoder.convert(message);
        mapData = decoder.convert(message);
        var data = mapData!['data'];
        var id = data['from'];
        var description = data['description'];

        var pc = _peerConnections[id];
        if (pc != null) {
          await pc.setRemoteDescription(
              RTCSessionDescription(description['sdp'], description['type']));
        }
      }
    };

    _socket?.candidateCallback = (message) async {
      var type = decoder.convert(message);

      if (type['type'] == 'candidate') {
        // JsonDecoder decoder = new JsonDecoder();
        // Map<String, dynamic> mapData = decoder.convert(message);
        mapData = decoder.convert(message);
        var data = mapData!['data'];
        var id = data['from'];
        var candidateMap = data['candidate'];
        var pc = _peerConnections[id];
        RTCIceCandidate candidate = RTCIceCandidate(candidateMap['candidate'],
            candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);
        if (pc != null) {
          await pc.addCandidate(candidate);
        } else {
          _remoteCandidates.add(candidate);
        }
      }
    };

    _socket?.leaveCallback = (message) async {
      var type = decoder.convert(message);

      if (type['type'] == 'leave') {
        // JsonDecoder decoder = new JsonDecoder();
        // Map<String, dynamic> mapData = decoder.convert(message);
        mapData = decoder.convert(message);
        var data = mapData!['data'];
        var id = data;
        var pc = _peerConnections.remove(id);
        _dataChannels.remove(id);

        if (_localStream != null) {
          _localStream?.dispose();
          _localStream = null;
        }

        if (pc != null) {
          pc.close();
        }
        _sessionId = '';
        if (onStateChange != null) {
          onStateChange!(SignalingState.CallStateBye);
        }
      }
    };

    _socket?.byeCallback = (message) async {
      var type = decoder.convert(message);

      if (type['type'] == 'bye') {
        mapData = decoder.convert(message);
        inspect(mapData);
        dynamic data = mapData!['data'];

        dynamic from = data['from'];
        dynamic to = data['to'];
        dynamic sessionId = data['session_id'];
        sessionId = sessionId;
        print('bye: ' + sessionId.toString());

        if (_localStream != null) {
          _localStream?.dispose();
          _localStream = null;
        }

        var pc = _peerConnections[to];
        if (pc != null) {
          pc.close();
          _peerConnections.remove(to);
        }

        var dc = _dataChannels[to];
        if (dc != null) {
          dc.close();
          _dataChannels.remove(to);
        }

        _sessionId = '';
        if (onStateChange != null) {
          onStateChange!(SignalingState.CallStateBye);
        }
      }
    };

    _socket?.keepaliveCallback = (message) async {
      var type = decoder.convert(message);

      if (type['type'] == 'keepalive') {
        print('keepalive response! ===================================');
      }
    };

    _socket?.onClose = (int code, String reason) {
      print('Closed by server [$code => $reason]!');
      if (onStateChange != null) {
        onStateChange!(SignalingState.ConnectionClosed);
      }
    };

    await _socket?.connect();
  }

  Future<MediaStream> createStream(media, user_screen) async {
    MediaStream stream;
    Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth':
              '640', // Provide your own width, height and frame rate here
          'minHeight': '480',
          'minFrameRate': '50',
        },
        'facingMode': 'user',
        'optional': [],
      }
      // 'video': true,
    };
    try {
      stream = user_screen
          ? await navigator.mediaDevices.getDisplayMedia(mediaConstraints)
          : await navigator.mediaDevices.getUserMedia(mediaConstraints);
      inspect(stream);
      if (onLocalStream != null) {
        onLocalStream!(stream);
      }
      if (stream.getAudioTracks() != null) {
        stream.getAudioTracks().forEach((element) {
          element.enableSpeakerphone(true);
        });
      }
    } catch (e) {
      print(e.toString());
      throw Exception('Failed to create MediaStream: ${e.toString()}');
    }
    print('stream $stream fjkdslg;jsldkfjgdsf');
    return stream;
  }

  _createPeerConnection(id, media, user_screen) async {
    RTCPeerConnection pc = await createPeerConnection(_iceServers, _config);

    pc.onTrack = (event) {
      // if (onAddRemoteStream != null) {
      inspect(event.streams);
      onAddRemoteStream!(event.streams[0]);
      // }
      _remoteStreams?.add(event.streams[0]);
    };
    if (media != 'data') {
      _localStream = await createStream(media, user_screen);
      // for (var track in localStream.getVideoTracks()) {
      //   pc.addTrack(track, localStream);
      // }
      _localStream!.getTracks().forEach((element) async {
        _senders.add(await pc.addTrack(element, _localStream!));
      });
    }
    // List<MediaStreamTrack> videoTracks = _xlocalStream!.getVideoTracks();

    pc.onIceCandidate = (candidate) async {
      Future.delayed(
          const Duration(seconds: 1),
          () => _send('candidate', {
                'to': id,
                'from': _selfId,
                'candidate': {
                  'sdpMLineIndex': candidate.sdpMLineIndex,
                  'sdpMid': candidate.sdpMid,
                  'candidate': candidate.candidate,
                },
                'session_id': _sessionId,
              }));
    };

    pc.onIceConnectionState = (state) {};

    pc.onRemoveTrack = (stream, track) {
      if (onRemoveRemoteStream != null) {
        final remoteStream = _localStream!;
        onRemoveRemoteStream!(remoteStream);
      }
    };

    pc.onDataChannel = (channel) {
      _addDataChannel(id, channel);
    };

    return pc;
  }

  // Future<MediaStream> createStream(media, user_screen) async {
  //   final Map<String, dynamic> mediaConstraints = {
  //     'audio': true,
  //     'video': {
  //       'mandatory': {
  //         'minWidth':
  //             '640', // Provide your own width, height and frame rate here
  //         'minHeight': '480',
  //         'minFrameRate': '30',
  //       },
  //       'facingMode': 'user',
  //       'optional': [],
  //     }
  //   };

  //   MediaStream stream = user_screen
  //       ? await navigator.mediaDevices.getDisplayMedia(mediaConstraints)
  //       : await navigator.mediaDevices.getUserMedia(mediaConstraints);
  //   if (this.onLocalStream != null) {
  //     this.onLocalStream!(stream);
  //   }
  //   return stream;
  // }

  // _createPeerConnection(id, media, user_screen) async {
  //   if (media != 'data') _localStream = await createStream(media, user_screen);
  //   RTCPeerConnection pc = await createPeerConnection(_iceServers, _config);
  //   if (media != 'data') pc.addStream(_localStream!);
  //   pc.onIceCandidate = (candidate) {
  //     _send('candidate', {
  //       'to': id,
  //       'candidate': {
  //         'sdpMLineIndex': candidate.sdpMLineIndex,
  //         'sdpMid': candidate.sdpMid,
  //         'candidate': candidate.candidate,
  //       },
  //       'session_id': this._sessionId,
  //     });
  //   };

  //   pc.onIceConnectionState = (state) {};

  //   pc.onAddStream = (stream) {
  //     if (this.onAddRemoteStream != null) this.onAddRemoteStream!(stream);
  //     //_remoteStreams.add(stream);
  //   };

  //   pc.onRemoveStream = (stream) {
  //     if (this.onRemoveRemoteStream != null) this.onRemoveRemoteStream!(stream);
  //     _remoteStreams?.removeWhere((it) {
  //       return (it.id == stream.id);
  //     });
  //   };

  //   pc.onDataChannel = (channel) {
  //     _addDataChannel(id, channel);
  //   };

  //   return pc;
  // }

  _addDataChannel(id, RTCDataChannel channel) {
    channel.onDataChannelState = (e) {};
    channel.onMessage = (RTCDataChannelMessage data) {
      if (onDataChannelMessage != null) onDataChannelMessage!(channel, data);
    };
    _dataChannels[id] = channel;

    if (onDataChannel != null) onDataChannel!(channel);
  }

  _createDataChannel(id, RTCPeerConnection pc, {label = 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit();
    RTCDataChannel channel = await pc.createDataChannel(label, dataChannelDict);
    _addDataChannel(id, channel);
  }

  _createOffer(String id, RTCPeerConnection pc, String media) async {
    try {
      RTCSessionDescription s = await pc
          .createOffer(media == 'data' ? _dc_constraints : _constraints);
      pc.setLocalDescription(s);
      _send('offer', {
        'to': id,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': _sessionId,
        'media': media,
      });
    } catch (e) {
      print(e.toString());
    }
  }

  _createAnswer(String id, RTCPeerConnection pc, media) async {
    try {
      RTCSessionDescription s = await pc
          .createAnswer(media == 'data' ? _dc_constraints : _constraints);
      pc.setLocalDescription(s);
      _send('answer', {
        'to': id,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': _sessionId,
      });
    } catch (e) {
      print(e.toString());
    }
  }

  _send(event, data) {
    // data['type'] = event;
    JsonEncoder encoder = const JsonEncoder();
    _socket?.send(event, encoder.convert(data));
  }
}
