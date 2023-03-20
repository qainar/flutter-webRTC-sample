library random_string;

import 'dart:math';

const asciiStart = 33;
const asciiEnd = 126;
const numericStart = 48;
const numericEnd = 57;
const lowerAlphaStart = 97;
const lowerAlphaEnd = 122;
const upperAlphaStart = 65;
const upperAlphaEnd = 90;

int randomBetween(int from, int to) {
  if (from > to) throw Exception('$from cannot be higher $to');
  var random = Random();
  return ((to - from) * random.nextDouble()).toInt() + from;
}

String randomString(int length, {int from = asciiStart, int to = asciiEnd}) {
  return String.fromCharCodes(
      List.generate(length, (index) => randomBetween(from, to)));
}

String randomNumeric(int length) =>
    randomString(length, from: numericStart, to: numericEnd);
