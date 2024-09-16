import 'dart:async';

Future<double> countTokensAsync(String text) async {
  // Simulate an asynchronous operation
  await Future.delayed(Duration(seconds: 1));

  // Split the text into words (tokens) using a regular expression
  List<String> tokens = text.split(RegExp(r'\W+'));

  // Remove empty tokens
  tokens.removeWhere((token) => token.isEmpty);

  // Return the count of tokens
  return tokens.length.toDouble();
}
