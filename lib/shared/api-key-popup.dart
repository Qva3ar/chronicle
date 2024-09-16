// api_key_popup.dart
import 'package:flutter/material.dart';
import 'package:Chrono/helpers/api-key-options.dart';
import 'package:Chrono/services/gpt-note-bind.service.dart';
import 'package:url_launcher/url_launcher.dart';

class ApiKeyPopup extends StatefulWidget {
  @override
  _ApiKeyPopupState createState() => _ApiKeyPopupState();
}

class _ApiKeyPopupState extends State<ApiKeyPopup> {
  String apiKey = '';
  String selectedModel = ''; // Default model

  String url1 = 'https://www.merge.dev/blog/chatgpt-api-key';
  String url2 = 'https://www.splendidfinancing.com/blog/how-to-get-an-openai-api-key-for-chatgpt';

  GPTNoteBindService gptNoteBindService = GPTNoteBindService();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    apiKey = gptNoteBindService.getKey;
    selectedModel = gptNoteBindService.getModel;
  }

  Future<void> _launchUrl(_url) async {
    final url = Uri.parse(_url);

    if (!await launchUrl(url)) {
      throw Exception('Could not launch $_url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enter GPT API Key'),
      //width fit content

      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: TextEditingController(text: apiKey),
              maxLines: null,
              onChanged: (value) {
                apiKey = value;
              },
              decoration: InputDecoration(labelText: 'API Key'),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedModel,
              items: apiKeyOptions
                  .map((item) => DropdownMenuItem<String>(
                        value: item.value,
                        child: Text(item.label),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedModel = value!;
                });
              },
              decoration: InputDecoration(labelText: 'Select Model'),
            ),
            SizedBox(
              height: 16,
            ),
            TextButton(
              onPressed: () {
                _launchUrl(url1);
              },
              child: Text('How to get API Key'),
            ),
            TextButton(
              onPressed: () {
                _launchUrl(url2);
              },
              child: Text('How to get API Key 2'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // Use the apiKey as needed (e.g., send it to an API)
            //print('API Key entered: $apiKey');
            gptNoteBindService.setKey(apiKey);
            gptNoteBindService.setModel(selectedModel);
            Navigator.of(context).pop();
          },
          child: Text('Submit'),
        ),
      ],
    );
  }
}
