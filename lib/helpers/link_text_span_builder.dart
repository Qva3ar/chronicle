import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkTextSpanBuilder extends SpecialTextSpanBuilder {
  @override
  TextSpan build(String data, {TextStyle? textStyle, SpecialTextGestureTapCallback? onTap}) {
    if (data == '') {
      return TextSpan(text: data, style: textStyle);
    }

    final List<TextSpan> inlineSpans = <TextSpan>[];
    if (data.length > 0) {
      final RegExp _urlRegex = RegExp(
        r'((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?',
        caseSensitive: false,
      );

      final Iterable<Match> matches = _urlRegex.allMatches(data);
      int start = 0;
      for (final Match match in matches) {
        if (match.start > start) {
          inlineSpans.add(
            TextSpan(
              text: data.substring(start, match.start),
              style: textStyle,
            ),
          );
        }

        final String url = data.substring(match.start, match.end);
        inlineSpans.add(
          TextSpan(
            text: url,
            style: textStyle?.copyWith(color: Colors.lightBlueAccent, decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                var launchUrlStr = url;
                if (!url.startsWith('http')) {
                  launchUrlStr = 'https://$url';
                }
                final Uri uri = Uri.parse(launchUrlStr);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
          ),
        );
        start = match.end;
      }

      if (start < data.length) {
        inlineSpans.add(
          TextSpan(
            text: data.substring(start),
            style: textStyle,
          ),
        );
      }
    }

    return TextSpan(children: inlineSpans, style: textStyle);
  }

  @override
  SpecialText? createSpecialText(String flag, {TextStyle? textStyle, SpecialTextGestureTapCallback? onTap, int? index}) {
    // We are manually building spans in build(), so this can be null unless we use specific delimiters
    return null;
  }
}

