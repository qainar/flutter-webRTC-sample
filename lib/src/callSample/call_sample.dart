import 'package:flutter/material.dart';
import 'dart:core';
import 'signalling.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallSample extends StatefulWidget {
  final String ip;
  const CallSample({Key? key, required this.ip}) : super(key: key);

  @override
  CallSampleState createState() => CallSampleState();
}

class CallSampleState extends State<CallSample> {
  Signaling? _signaling;
  List<dynamic>? _peers;
  dynamic _selfId;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  late final String serverIP;

  @override
  initState() {
    super.initState();
    initRenderers();
    _connect();
    Future.delayed(const Duration(seconds: 3), () => {setState(() {})});
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    setState(() {});
  }

  @override
  deactivate() {
    super.deactivate();
    if (_signaling != null) _signaling?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  void _connect() async {
    if (_signaling == null) {
      _signaling = Signaling(serverIP)..connect();

      _signaling?.onStateChange = (SignalingState state) {
        switch (state) {
          case SignalingState.callStateNew:
            _inCalling = true;
            initRenderers();

            break;
          case SignalingState.callStateBye:
            setState(() {
              _localRenderer.srcObject = null;
              _remoteRenderer.srcObject = null;
              _inCalling = false;
            });
            break;
          case SignalingState.callStateInvite:
          case SignalingState.callStateConnected:
          case SignalingState.callStateRinging:
          case SignalingState.connectionClosed:
          case SignalingState.connectionError:
          case SignalingState.connectionOpen:
            break;
        }
      };

      _signaling?.onPeersUpdate = ((event) {
        if (mounted) {
          setState(() {
            _selfId = event['self'];
            _peers = event['peers'];
          });
        }
      });

      _signaling?.onLocalStream = ((stream) {
        _localRenderer.srcObject = stream;
        initRenderers();
      });

      _signaling?.onAddRemoteStream = ((stream) {
        _remoteRenderer.srcObject = stream;
        initRenderers();
      });

      _signaling?.onRemoveRemoteStream = ((stream) {
        _remoteRenderer.srcObject = null;
      });
    }
  }

  _invitePeer(context, peerId, useSreen) async {
    if (_signaling != null && peerId != _selfId) {
      _signaling?.invite(peerId, 'video', useSreen);
    }
  }

  _hangUp() {
    if (_signaling != null) {
      _signaling?.bye();
    }
  }

  _switchCamera() {
    _signaling?.switchCamera();
  }

  _muteMic() {
    _signaling?.muteMic();
  }

  _buildRow(context, peer) {
    var self = (peer['id'] == _selfId);
    return ListBody(children: <Widget>[
      ListTile(
        title: Text(self
            ? peer['name'] + '[Your self]'
            : peer['name'] + '[' + peer['user_agent'] + ']'),
        onTap: null,
        trailing: SizedBox(
            width: 100.0,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.videocam),
                    onPressed: () => {
                      _invitePeer(context, peer['id'], false),
                    },
                    tooltip: 'Video calling',
                  ),
                  IconButton(
                    icon: const Icon(Icons.screen_share),
                    onPressed: () => _invitePeer(context, peer['id'], true),
                    tooltip: 'Screen sharing',
                  )
                ])),
        subtitle: Text('id: ${peer['id']}'),
      ),
      const Divider()
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P Call Sample'),
        automaticallyImplyLeading: false,
        leading: BackButton(
          onPressed: () {
            _signaling?.whenclose();
          },
        ),
        actions: const <Widget>[
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: null,
            tooltip: 'setup',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _inCalling
          ? SizedBox(
              width: 200.0,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    FloatingActionButton(
                      onPressed: _switchCamera,
                      child: const Icon(Icons.switch_camera),
                    ),
                    FloatingActionButton(
                      onPressed: _hangUp,
                      tooltip: 'Hangup',
                      backgroundColor: Colors.pink,
                      child: const Icon(Icons.call_end),
                    ),
                    FloatingActionButton(
                      onPressed: _muteMic,
                      child: const Icon(Icons.mic_off),
                    )
                  ]))
          : null,
      body: _inCalling
          ? OrientationBuilder(builder: (context, orientation) {
              return Stack(children: <Widget>[
                Positioned(
                    left: 0.0,
                    right: 0.0,
                    top: 0.0,
                    bottom: 0.0,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      decoration: const BoxDecoration(color: Colors.black54),
                      child: RTCVideoView(_remoteRenderer),
                    )),
                Positioned(
                  left: 20.0,
                  top: 20.0,
                  child: Container(
                    width: orientation == Orientation.portrait ? 90.0 : 120.0,
                    height: orientation == Orientation.portrait ? 120.0 : 90.0,
                    decoration: const BoxDecoration(color: Colors.black54),
                    child: RTCVideoView(_localRenderer),
                  ),
                ),
              ]);
            })
          : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(0.0),
              itemCount: (_peers != null ? _peers?.length : 0),
              itemBuilder: (context, i) {
                return _buildRow(context, _peers?[i]);
              }),
    );
  }
}
