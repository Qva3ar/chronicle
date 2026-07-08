// api_key_popup.dart
import 'package:flutter/material.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/helpers/api-key-options.dart';
import 'package:chrono/services/gpt-note-bind.service.dart';
import 'package:url_launcher/url_launcher.dart';

class ApiKeyPopup extends StatefulWidget {
  @override
  _ApiKeyPopupState createState() => _ApiKeyPopupState();
}

class _ApiKeyPopupState extends State<ApiKeyPopup> {
  late final TextEditingController _openAiController;
  late final TextEditingController _geminiController;

  String selectedModel = '';

  String url1 = 'https://www.merge.dev/blog/chatgpt-api-key';
  String url2 = 'https://www.splendidfinancing.com/blog/how-to-get-an-openai-api-key-for-chatgpt';
  String geminiUrl = 'https://aistudio.google.com/app/apikey';

  GPTNoteBindService gptNoteBindService = GPTNoteBindService();

  @override
  void initState() {
    super.initState();
    _openAiController = TextEditingController(text: gptNoteBindService.getKey);
    _geminiController = TextEditingController(text: gptNoteBindService.getGeminiKey);
    selectedModel = gptNoteBindService.getModel;
  }

  @override
  void dispose() {
    _openAiController.dispose();
    _geminiController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(_url) async {
    final url = Uri.parse(_url);

    if (!await launchUrl(url)) {
      throw Exception('Could not launch $_url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedOption = apiKeyOptions.firstWhere((item) => item.value == selectedModel,
        orElse: () => apiKeyOptions.first);
    
    // We can highlight the corresponding key field based on the selected model's provider
    final isGeminiModel = selectedOption.provider == 'gemini';

    InputDecoration keyFieldDecoration({
      required String label,
      required bool isActive,
    }) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          color: isActive ? MyColors.orangeDivider : textSecondary,
        ),
      );
    }

    return AlertDialog(
      title: Text('API Access Settings'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedModel,
              items: apiKeyOptions
                  .map((item) => DropdownMenuItem<String>(
                        value: item.value,
                        child: Text(
                          item.displayLabel,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ))
                  .toList(),
              selectedItemBuilder: (context) => apiKeyOptions
                  .map(
                    (item) => Text(
                      item.label.isEmpty ? 'Select Model' : item.label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedModel = value!;
                });
              },
              decoration: const InputDecoration(labelText: 'Select Model'),
            ),
            if (selectedOption.speedLabel != null &&
                selectedOption.speedLabel!.isNotEmpty) ...[
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Задержка до ответа: ${selectedOption.speedLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ],
            if (selectedOption.tpm != null) ...[
              SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Token limit: ${selectedOption.tpm}'),
                  ],
                ),
              ),
            ],
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            // OpenAI Key Field
            TextField(
              controller: _openAiController,
              maxLines: null,
              style: const TextStyle(color: textPrimary),
              decoration: keyFieldDecoration(
                label: 'OpenAI API Key',
                isActive: !isGeminiModel,
              ),
            ),
            SizedBox(height: 16),
            // Gemini Key Field
            TextField(
              controller: _geminiController,
              maxLines: null,
              style: const TextStyle(color: textPrimary),
              decoration: keyFieldDecoration(
                label: 'Gemini API Key',
                isActive: isGeminiModel,
              ),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              children: [
                TextButton(
                  onPressed: () {
                    _launchUrl(url1);
                  },
                  child: Text('Get OpenAI Key'),
                ),
                TextButton(
                  onPressed: () {
                    _launchUrl(geminiUrl);
                  },
                  child: Text('Get Gemini Key'),
                ),
              ],
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
            gptNoteBindService.setKey(_openAiController.text);
            gptNoteBindService.setGeminiKey(_geminiController.text);
            gptNoteBindService.setModel(selectedModel);
            Navigator.of(context).pop();
          },
          child: Text('Submit'),
        ),
      ],
    );
  }
}
