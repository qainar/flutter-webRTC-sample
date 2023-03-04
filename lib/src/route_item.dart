import 'package:flutter/material.dart';
import 'dart:core';

typedef RouteCallBack = void Function(BuildContext context);

class RouteItem {
  RouteItem({required this.title, required this.push});
  final String title;
  final RouteCallBack push;
}