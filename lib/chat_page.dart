import 'dart:async';
import 'dart:developer';

import 'package:chrono/models/tag.dart';
import 'package:chrono/record.service.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/helpers/token.helper.dart';
import 'package:chrono/message_bubble.dart';
import 'package:chrono/message_composer.dart';
import 'package:chrono/models/record.dart';
import 'package:chrono/services/gpt-note-bind.service.dart';
import 'package:chrono/services/gpt.service.dart';
import 'package:chrono/services/messages.service.dart';
import 'package:chrono/shared/instructions-block.dart';
import 'package:chrono/shared/instructions.dart';
import 'package:chrono/shared/tag_selection_dialog.dart';

import 'package:chrono/helpers/api-key-options.dart';
import 'db_manager.dart';
import 'models/chat-message.dart';
import 'package:chrono/ai/ai_client.dart';
import 'dart:convert';

class ChatPage extends StatefulWidget {
  final MessageService messageService; // Add this field

  ChatPage({Key? key, required this.messageService}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messages = <ChatMessage>[];
  final List<Record> allRecords = [];
  List<Tag> allTags = [];

  var _awaitingResponse = false;
  var includeAllNote = false;
  List<int> selectedTagIds = []; // Store selected tag IDs for AI context
  final TextEditingController _textController = TextEditingController();
  final dbHelper = DatabaseHelper.instance;
  late StreamSubscription<OpenAIStreamChatCompletionModel> stream;

  double tokenCount = 0;
  bool isTokenCounting = false;
  bool _isProcessingChunks = false;
  int _currentChunk = 0;
  int _totalChunks = 0;

  GPTService gptService = GPTService();
  GPTNoteBindService gptNoteBindService = GPTNoteBindService();
  RecordService recordService = RecordService();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    if (widget.messageService.getLast20Messages().isNotEmpty) {
      _messages.addAll(widget.messageService.getLast20Messages());
    } else {
      _messages.add(ChatMessage('Hello, how can I help?', false, false));
    }

    getAllTags();
  }

  void getAllTags() async {
    allTags = await recordService.queryAllTagsJust();
    // allTags = await recordService.queryAllTagsJust();
  }

  getUserNotes() async {
    List<Record> newRecords;

    // Fetch records based on selected tags or all records
    if (selectedTagIds.isNotEmpty) {
      newRecords = await dbHelper.getRecordsByMultipleTags(selectedTagIds);
    } else {
      newRecords = await recordService.queryRecords();
    }

    allRecords.clear();
    if (newRecords.isNotEmpty) {
      allRecords.addAll(newRecords);
    }

    final count = await processMessages(allRecords);
    //find model from apitokenoptions and get price
    final model =
        apiKeyOptions.firstWhere((element) => element.value == gptNoteBindService.getModel);
    //round to 2 digits
    String inString = (count / 1000 * model.price).toStringAsFixed(8);

    setState(() {
      isTokenCounting = false;
      tokenCount = double.parse(inString);
    });
  }

  String extractValue(String input) {
    RegExp regExp = RegExp(r'Found:\s*\[(.*?)\]');
    Match? match = regExp.firstMatch(input);

    if (match != null) {
      return match.group(1)!; // group(1) contains the value within square brackets
    } else {
      return ""; // Return an empty string if no match is found
    }
  }

  showErrorDialog(String errorMessage) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Unexpected Error'),
            content: Text(
              'Error: $errorMessage',
              style: TextStyle(color: Colors.black),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        });
  }

  Future<bool> showChunkingConfirmationDialog(int estimatedChunks) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            'Context Too Large',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your selected context exceeds the model\'s limit.',
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 12),
              Text(
                'We can split it into approximately $estimatedChunks chunks and process them sequentially. The AI will receive all context before responding.',
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
              SizedBox(height: 12),
              Text(
                'Note: This may take longer and cost more.',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.primaryColor,
              ),
              child: Text('Continue with Chunking', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  List<List<Record>> _splitRecordsIntoChunks(List<Record> records) {
    // Estimate tokens per record (rough estimate: 1 character ≈ 0.25 tokens)
    // Conservative chunk size: 6000 tokens per chunk (leaving room for system messages)
    const maxTokensPerChunk = 6000;
    const charsPerToken = 4.0;
    final maxCharsPerChunk = (maxTokensPerChunk * charsPerToken).toInt();

    List<List<Record>> chunks = [];
    List<Record> currentChunk = [];
    int currentChunkSize = 0;

    // Sort records by tag to keep semantic groups together
    final sortedRecords = List<Record>.from(records);
    sortedRecords.sort((a, b) {
      final aFirstTag = a.tagIds.isNotEmpty ? a.tagIds.first : 0;
      final bFirstTag = b.tagIds.isNotEmpty ? b.tagIds.first : 0;
      return aFirstTag.compareTo(bFirstTag);
    });

    for (final record in sortedRecords) {
      final recordSize = record.text.length;

      // If adding this record would exceed the chunk size, start a new chunk
      if (currentChunkSize + recordSize > maxCharsPerChunk && currentChunk.isNotEmpty) {
        chunks.add(List<Record>.from(currentChunk));
        currentChunk = [record];
        currentChunkSize = recordSize;
      } else {
        currentChunk.add(record);
        currentChunkSize += recordSize;
      }
    }

    // Add the last chunk if it's not empty
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }

    return chunks;
  }

  String _createChunkInstruction(
      int chunkNumber, int totalChunks, List<Record> records, bool isLast, String? userQuery) {
    final notesString = records.map((note) {
      String tagIds = note.tagIds.map((tagId) => "$tagId").join(', ');
      return "NoteId ${note.id}:\nText: ${note.text}\nTag IDs: ${tagIds}\nCreated At: ${note.createdAt}\n\n";
    }).join('\n');

    final tags = allTags.map((tag) {
      return "tagId: ${tag.id}; tagName: ${tag.name}";
    }).join(', ');

    if (isLast) {
      return "This is the FINAL chunk ($chunkNumber of $totalChunks) of the user's personal data. All context has now been provided. Here are the remaining notes:\n\n$notesString\n\nAll my tags: $tags\nMy local time: ${DateTime.now()}\n\nYou now have the complete context. Please respond thoughtfully to the user's question: \"$userQuery\"";
    } else if (chunkNumber == 1) {
      return "IMPORTANT: This is chunk $chunkNumber of $totalChunks. I'm providing you with my personal data (notes/records) in multiple chunks. DO NOT RESPOND until you receive the final chunk. Just acknowledge and wait. Here are the notes for chunk $chunkNumber:\n\n$notesString";
    } else {
      return "This is chunk $chunkNumber of $totalChunks. Continue receiving context. DO NOT RESPOND YET. Here are more notes:\n\n$notesString";
    }
  }

  Future<void> _submitWithChunking(String userQuery, List<Record> records) async {
    final chunks = _splitRecordsIntoChunks(records);

    setState(() {
      _isProcessingChunks = true;
      _totalChunks = chunks.length;
      _currentChunk = 0;
    });

    try {
      // Send each chunk sequentially
      for (int i = 0; i < chunks.length; i++) {
        setState(() {
          _currentChunk = i + 1;
        });

        final isLastChunk = i == chunks.length - 1;
        final chunkInstruction = _createChunkInstruction(
          i + 1,
          chunks.length,
          chunks[i],
          isLastChunk,
          userQuery,
        );

        // Create system message for this chunk
        final List<ChatMessage> chunkSystemMessages = [
          ChatMessage(chunkInstruction, false, true),
        ];

        // Only for the last chunk, we stream the response
        if (isLastChunk) {
          String accumulator = '';
          _messages.insert(0, ChatMessage("", false, false));

          final completer = Completer<void>();

          stream = gptService.completionStream(_messages, chunkSystemMessages).listen((event) {
            final content = event.choices.first.delta.content;
            if (content != null && content.isNotEmpty) {
              accumulator += content[0].text ?? '';
            }

            _messages.first.content = accumulator;
            setState(() {});
          }, onError: (err) {
            completer.completeError(err);
          }, onDone: () {
            final ids = extractValue(accumulator);
            _messages.first.recordIds = ids;
            widget.messageService.addMessage(ChatMessage(accumulator, false, false));
            completer.complete();
          });

          await completer.future;
        } else {
          // For non-last chunks, send without streaming (just to feed context)
          // We create a temporary message list to send the chunk
          final tempMessages = List<ChatMessage>.from(_messages);
          tempMessages.insert(
              0, ChatMessage("Acknowledged. Waiting for next chunk.", false, false));

          final completer = Completer<void>();

          stream = gptService.completionStream(tempMessages, chunkSystemMessages).listen((event) {
            // We don't care about the response for intermediate chunks
          }, onError: (err) {
            completer.completeError(err);
          }, onDone: () {
            completer.complete();
          });

          await completer.future;

          // Small delay between chunks
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
    } catch (err) {
      log('Error during chunked submission: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during chunked processing: $err')),
        );
      }
    } finally {
      setState(() {
        _isProcessingChunks = false;
        _awaitingResponse = false;
        _currentChunk = 0;
        _totalChunks = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cardColor,
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: Color(0x0d2196f3),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // Опция reverse
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return MessageBubble(
                  content: msg.content,
                  isNoteEditing: false,
                  isUserMessage: msg.isUserMessage,
                  recordIds: msg.recordIds,
                );
              },
            ),
          ),
          InstructionsBlockWidget(onSubmitted: _onSubmitted),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Include user data",
                              style: TextStyle(color: Colors.white),
                            ),
                            if (includeAllNote && selectedTagIds.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: InkWell(
                                  onTap: () async {
                                    // Allow re-opening dialog to change selection
                                    final result = await showDialog<List<int>?>(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return TagSelectionDialog(
                                          availableTags: allTags,
                                          initialSelectedTagIds: selectedTagIds,
                                        );
                                      },
                                    );

                                    if (result != null && result.isNotEmpty) {
                                      setState(() {
                                        selectedTagIds = result;
                                      });
                                      getUserNotes();
                                    } else if (result != null && result.isEmpty) {
                                      // User confirmed with no tags - turn off
                                      setState(() {
                                        includeAllNote = false;
                                        selectedTagIds = [];
                                        tokenCount = 0;
                                      });
                                    }
                                  },
                                  child: Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (includeAllNote && selectedTagIds.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 4.0,
                              runSpacing: 4.0,
                              children: allTags
                                  .where((tag) => selectedTagIds.contains(tag.id))
                                  .map((tag) => Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color(int.parse(tag.color!)),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          tag.name,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: includeAllNote,
                    onChanged: (newValue) async {
                      if (newValue) {
                        // Show tag selection dialog
                        final result = await showDialog<List<int>?>(
                          context: context,
                          builder: (BuildContext context) {
                            return TagSelectionDialog(
                              availableTags: allTags,
                              initialSelectedTagIds: selectedTagIds,
                            );
                          },
                        );

                        // Handle dialog result
                        if (result != null && result.isNotEmpty) {
                          // User confirmed with tags selected
                          setState(() {
                            selectedTagIds = result;
                            includeAllNote = true;
                          });
                          getUserNotes();
                        } else {
                          // User cancelled or confirmed with no tags
                          setState(() {
                            includeAllNote = false;
                            selectedTagIds = [];
                            tokenCount = 0;
                          });
                        }
                      } else {
                        // Turning switch OFF
                        setState(() {
                          includeAllNote = false;
                          selectedTagIds = [];
                          tokenCount = 0;
                        });
                      }
                    },
                  ),
                ]),
              ],
            ),
          ),
          if (includeAllNote)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: isTokenCounting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Counting tokens...',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    )
                  : Text(
                      'Cost: ~\$$tokenCount',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
            ),
          if (_isProcessingChunks)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: MyColors.fivyColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MyColors.fivyColor.withAlpha(77),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Processing chunk $_currentChunk/$_totalChunks',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          MessageComposer(
            onSubmitted: _onSubmitted,
            onStop: onStop,
            awaitingResponse: _awaitingResponse,
          ),
        ],
      ),
    );
  }

  onStop() {
    stream.cancel();
    setState(() {
      _awaitingResponse = false;
    });
  }

  Future<double> processMessages(List<Record> messages) async {
    setState(() {
      isTokenCounting = true;
    });
    // Concatenate messages into a single string
    final combinedMessages = messages.map((message) => message.text).join(' ');
    // //print(combinedMessages);
    // Count tokens asynchronously
    return await countTokensAsync(combinedMessages);
  }

  Future<void> _onSubmitted(String message) async {
    List<ChatMessage> _systemMessages = [];
    final userMessage = ChatMessage(message, true, false);
    setState(() {
      _messages.insert(0, userMessage); // Вставка в начало спискаs
      _awaitingResponse = true;
    });
    _extractAndStoreInterest(message); // fire-and-forget
    widget.messageService.addMessage(userMessage);
    _textController.clear(); // Очистка текстового поля

    String accumulator = '';

    if (includeAllNote) {
      _systemMessages
          .add(ChatMessage(Instractions.useUserAllNotes(allRecords, allTags), false, true));
      log(Instractions.useUserAllNotes(allRecords, allTags));
    }
    // _systemMessages.add(ChatMessage(Instractions.findRecords(), false, true));

    try {
      //_messages as string

      _messages.insert(0, ChatMessage("", false, false));
      stream = gptService.completionStream(_messages, _systemMessages).listen((event) {
        final content = event.choices.first.delta.content;
        //print(content);
        if (content != null && content.isNotEmpty) {
          accumulator += content[0].text ?? '';
        }

        if (event.choices.first.finishReason == 'stop') {}
        _messages.first.content = accumulator;
        setState(() {});
      }, onError: (err) async {
        if (err is RequestFailedException) {
          final errorMessage = err.message;
          log('API Error: $errorMessage');

          // Check if error is related to context length
          final isContextLengthError =
              errorMessage.toLowerCase().contains('maximum context length') ||
                  errorMessage.toLowerCase().contains('context_length_exceeded') ||
                  errorMessage.toLowerCase().contains('too many tokens') ||
                  errorMessage.toLowerCase().contains('token limit');

          if (isContextLengthError && includeAllNote && allRecords.isNotEmpty) {
            // Context is too large - offer chunking
            setState(() {
              _awaitingResponse = false;
            });

            // Remove the empty message we inserted
            if (_messages.isNotEmpty && _messages.first.content.isEmpty) {
              _messages.removeAt(0);
            }

            // Estimate number of chunks
            final chunks = _splitRecordsIntoChunks(allRecords);
            final shouldProceed = await showChunkingConfirmationDialog(chunks.length);

            if (shouldProceed) {
              // User confirmed - proceed with chunking
              setState(() {
                _awaitingResponse = true;
              });
              await _submitWithChunking(message, allRecords);
            } else {
              // User cancelled
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Request cancelled.')),
                );
              }
            }
          } else {
            // Other API error
            showErrorDialog(errorMessage);
            setState(() {
              _awaitingResponse = false;
            });
          }
        } else {
          // Handle other exceptions
          log('Unexpected error: $err');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('An unexpected error occurred. Please try again.')),
            );
          }
          setState(() {
            _awaitingResponse = false;
          });
        }
      }, onDone: () {
        final ids = extractValue(accumulator);
        _messages.first.recordIds = ids;
        widget.messageService.addMessage(ChatMessage(accumulator, false, false));
        setState(() {
          _awaitingResponse = false;
        });
      });
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Please try again.')),
        );
      }
      setState(() {
        _awaitingResponse = false;
      });
    }
  }

  Future<void> _extractAndStoreInterest(String text) async {
    try {
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        print('[Interests] Skip empty chat message');
        return;
      }
      final preview = trimmed.length > 120 ? '${trimmed.substring(0, 120)}…' : trimmed;
      print('[Interests] Extracting topics from: "$preview"');
      final sys = 'Извлеки краткие темы интересов и намерение из пользовательского сообщения. '
          'Ответ только JSON с полями: topics (array of strings, ≤3), intent (string), confidence (0..1).';
      final raw = await AiClient.instance.completeJson(
        systemPrompt: sys,
        userPrompt: text,
      );
      print('[Interests] Raw extractor response: $raw');
      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        parsed = {
          'topics': [],
          'intent': null,
          'confidence': 0.5,
        };
        print('[Interests] Failed to parse JSON, using fallback.');
      }
      final topics = (parsed['topics'] is List) ? (parsed['topics'] as List) : <String>[];
      final intent = parsed['intent']?.toString();
      final confidence =
          parsed['confidence'] is num ? (parsed['confidence'] as num).toDouble() : 0.5;
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (topics.isEmpty && intent == null) {
        print('[Interests] Nothing to store (no topics/intent).');
        return;
      }
      if (topics.isEmpty) {
        await db.insert(DatabaseTables.aiInterestSignals, {
          DatabaseColumns.aiSource: 'chat',
          DatabaseColumns.aiSourceId: now.toString(),
          DatabaseColumns.aiTopic: 'general',
          DatabaseColumns.aiIntent: intent,
          DatabaseColumns.aiConfidence: confidence,
          DatabaseColumns.aiCreatedAt: now,
        });
        print('[Interests] Stored generic interest intent="$intent" conf=$confidence');
      } else {
        for (final t in topics.take(3)) {
          await db.insert(DatabaseTables.aiInterestSignals, {
            DatabaseColumns.aiSource: 'chat',
            DatabaseColumns.aiSourceId: now.toString(),
            DatabaseColumns.aiTopic: t.toString(),
            DatabaseColumns.aiIntent: intent,
            DatabaseColumns.aiConfidence: confidence,
            DatabaseColumns.aiCreatedAt: now,
          });
          print('[Interests] Stored topic="$t" intent="$intent" conf=$confidence');
        }
      }
    } catch (e, stack) {
      print('[Interests] ERROR: $e');
      print(stack);
    }
  }
}
