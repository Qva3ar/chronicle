import 'dart:convert';

import 'package:chrono/ai/ai_client.dart';
import 'package:chrono/models/record.dart';
import 'package:chrono/models/tag.dart';

/// Finds note ids relevant to a user prompt using chunked AI calls.
class WorkspaceAiService {
  static const int _maxTokensPerChunk = 6000;
  static const double _charsPerToken = 4.0;

  static List<List<Record>> splitRecordsIntoChunks(List<Record> records) {
    final maxCharsPerChunk = (_maxTokensPerChunk * _charsPerToken).toInt();
    final chunks = <List<Record>>[];
    var currentChunk = <Record>[];
    var currentChunkSize = 0;

    final sortedRecords = List<Record>.from(records);
    sortedRecords.sort((a, b) {
      final aFirstTag = a.tagIds.isNotEmpty ? a.tagIds.first : 0;
      final bFirstTag = b.tagIds.isNotEmpty ? b.tagIds.first : 0;
      return aFirstTag.compareTo(bFirstTag);
    });

    for (final record in sortedRecords) {
      final recordSize = record.text.length + record.title.length + 32;
      if (currentChunkSize + recordSize > maxCharsPerChunk && currentChunk.isNotEmpty) {
        chunks.add(List<Record>.from(currentChunk));
        currentChunk = [record];
        currentChunkSize = recordSize;
      } else {
        currentChunk.add(record);
        currentChunkSize += recordSize;
      }
    }
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }
    return chunks;
  }

  static String _tagsLine(List<Tag> allTags) {
    return allTags.map((t) => 'tagId:${t.id} name:${t.name}').join('; ');
  }

  static List<int> _parseIdsJson(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      final lines = s.split('\n');
      if (lines.length > 2) {
        s = lines.sublist(1, lines.length - 1).join('\n').trim();
      }
    }
    final decoded = jsonDecode(s);
    if (decoded is List) {
      return decoded
          .map((e) => e is int ? e : int.tryParse('$e'))
          .whereType<int>()
          .toList();
    }
    if (decoded is Map && decoded['ids'] is List) {
      return (decoded['ids'] as List)
          .map((e) => e is int ? e : int.tryParse('$e'))
          .whereType<int>()
          .toList();
    }
    return [];
  }

  /// Returns distinct note ids from [candidates] that match [userPrompt].
  static Future<List<int>> findRelatedNoteIds({
    required List<Record> candidates,
    required List<Tag> allTags,
    required String userPrompt,
  }) async {
    final unlocked =
        candidates.where((r) => !r.isLocked).toList();
    if (unlocked.isEmpty) return [];

    final trimmed = userPrompt.trim();
    if (trimmed.isEmpty) return [];

    final chunks = splitRecordsIntoChunks(unlocked);
    final found = <int>{};
    final tagsLine = _tagsLine(allTags);

    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final notesString = chunk.map((note) {
        final tagIds = note.tagIds.join(',');
        final date = DateTime.fromMillisecondsSinceEpoch(note.createdAt);
        return 'NoteId ${note.id}:\nTitle: ${note.title}\nText: ${note.text}\nTag IDs: $tagIds\nCreated: ${date.toIso8601String()}\n';
      }).join('\n---\n');

      final system = '''
You help select personal notes that match the user's request.
Tags reference: $tagsLine
Respond with ONLY valid JSON (no markdown): {"ids":[<int>,...]} listing note ids from THIS chunk that are relevant. Use [] if none.
Chunk ${i + 1} of ${chunks.length}.''';

      final user = 'User request:\n$trimmed\n\nNotes in this chunk:\n$notesString';

      final raw = await AiClient.instance.completeJson(
        systemPrompt: system,
        userPrompt: user,
        temperature: 0.2,
      );
      try {
        found.addAll(_parseIdsJson(raw));
      } catch (_) {
        // skip malformed chunk
      }
    }

    final validIds = unlocked.map((r) => r.id).toSet();
    return found.where(validIds.contains).toList()..sort();
  }
}
