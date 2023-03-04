import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'src/route_item.dart';
import 'src/utlis/key_value_store.dart';
import './src/callSample/call_sample.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';

void main() {
  if (WebRTC.platformIsDesktop) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  } else if (WebRTC.platformIsAndroid) {
    WidgetsFlutterBinding.ensureInitialized();
    startForegroundService();
  }
  HttpOverrides.global = MyHttpOverrides();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<bool> startForegroundService() async {
  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: 'Title of the notification',
    notificationText: 'Text of the notification',
    notificationImportance: AndroidNotificationImportance.Default,
    notificationIcon: AndroidResource(
        name: 'background_icon',
        defType: 'drawable'), // Default is ic_launcher from folder mipmap
  );
  await FlutterBackground.initialize(androidConfig: androidConfig);
  return FlutterBackground.enableBackgroundExecution();
}

enum DialogDemoAction {
  cancel,
  connect,
}

class _MyAppState extends State<MyApp> {
  late List<RouteItem> items;
  String _serverAddress = '';
  KeyValueStore keyValueStore = KeyValueStore();
  bool _datachannel = false;

  @override
  initState() {
    super.initState();
    _initItems();
    _initData();
  }

  _buildRow(context, item) {
    return ListBody(
      children: <Widget>[
        ListTile(
          title: Text(item.title),
          onTap: () => item.push(context),
          trailing: const Icon(Icons.arrow_right),
        ),
        Divider()
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('P2P call sample'),
        ),
        body: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.all(0.0),
            itemCount: items.length,
            itemBuilder: (context, i) {
              return _buildRow(context, items[i]);
            }),
      ),
    );
  }

  void showDialogDemo<type>(
      {required BuildContext context, required Widget child}) {
    showDialog<DialogDemoAction>(
        context: context,
        builder: (BuildContext context) => child).then((value) {
      if (value != null) {
        if (value == DialogDemoAction.connect) {
          keyValueStore.setString('server', _serverAddress);
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => CallSample(ip: _serverAddress)));
        }
      }
    });
  }

  _showAddressDialog(context) {
    showDialogDemo<DialogDemoAction>(
        context: context,
        child: AlertDialog(
          title: const Text('server address'),
          content: TextField(
            onChanged: (String text) {
              setState(() {
                _serverAddress = text;
              });
            },
            decoration: InputDecoration(
              hintText: _serverAddress,
            ),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () {
                  Navigator.pop(context, DialogDemoAction.cancel);
                },
                child: const Text('cancel')),
            TextButton(
                onPressed: () {
                  Navigator.pop(context, DialogDemoAction.connect);
                },
                child: const Text('connect'))
          ],
        ));
  }

  _initData() async {
    await keyValueStore.init();
    setState(() {
      _serverAddress = keyValueStore.getString('server') ?? '172.20.10.3';
    });
  }

  _initItems() {
    items = <RouteItem>[
      RouteItem(
          title: 'CallSample',
          push: (BuildContext context) {
            _datachannel = false;
            _showAddressDialog(context);
          })
    ];
  }
}
