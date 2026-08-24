import 'dart:convert';

import 'offline_mutation.dart';
import 'offline_mutation_store.dart';

class OfflineMutationQueue {
  OfflineMutationQueue({
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  Future<int> count() async {
    return (await load()).length;
  }

  Future<List<OfflineMutation>> load() async {
    final String? payload = await loadOfflineMutationPayload();
    if (payload == null || payload.trim().isEmpty) {
      return const <OfflineMutation>[];
    }

    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! List<dynamic>) {
        return const <OfflineMutation>[];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(OfflineMutation.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const <OfflineMutation>[];
    }
  }

  Future<OfflineMutation> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final List<OfflineMutation> mutations =
        (await load()).toList(growable: true);
    final DateTime now = _clock();
    final OfflineMutation mutation = OfflineMutation(
      id: '${now.microsecondsSinceEpoch}-${mutations.length}',
      method: method,
      path: path,
      body: body == null ? null : Map<String, dynamic>.of(body),
      createdAt: now,
    );

    mutations.add(mutation);
    await _save(mutations);
    return mutation;
  }

  Future<void> remove(String id) async {
    final List<OfflineMutation> mutations = (await load())
        .where((OfflineMutation mutation) => mutation.id != id)
        .toList(growable: false);
    await _save(mutations);
  }

  Future<void> replace(OfflineMutation replacement) async {
    final List<OfflineMutation> mutations = (await load())
        .map(
          (OfflineMutation mutation) =>
              mutation.id == replacement.id ? replacement : mutation,
        )
        .toList(growable: false);
    await _save(mutations);
  }

  Future<void> clear() async {
    await _save(const <OfflineMutation>[]);
  }

  Future<void> _save(List<OfflineMutation> mutations) async {
    await saveOfflineMutationPayload(
      jsonEncode(
        mutations
            .map((OfflineMutation mutation) => mutation.toJson())
            .toList(growable: false),
      ),
    );
  }
}
