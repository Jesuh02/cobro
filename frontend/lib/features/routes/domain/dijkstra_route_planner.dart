/// A geographic vertex in a weighted graph.
///
/// Coordinates are kept on the node so the resulting path can be rendered
/// directly by a map. Dijkstra itself only uses edge weights; callers can use
/// distance, travel time, cost, or any other non-negative metric.
class GeoNode<T> {
  const GeoNode({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.value,
  });

  final String id;
  final double latitude;
  final double longitude;
  final T value;
}

/// A directed weighted edge between two [GeoNode] identifiers.
///
/// Set [bidirectional] when the same cost applies in both directions.
class WeightedGeoEdge {
  const WeightedGeoEdge({
    required this.from,
    required this.to,
    required this.weight,
    this.bidirectional = false,
  });

  final String from;
  final String to;
  final double weight;
  final bool bidirectional;
}

/// The closest reachable destination and the shortest path leading to it.
class DijkstraPath<T> {
  DijkstraPath({
    required this.destination,
    required Iterable<GeoNode<T>> path,
    required this.distance,
  }) : path = List<GeoNode<T>>.unmodifiable(path);

  final GeoNode<T> destination;
  final List<GeoNode<T>> path;
  final double distance;
}

/// Finds shortest paths in a validated, immutable weighted graph.
///
/// Destination ties are resolved by the lexicographically smaller node id.
/// Neighbours and queue entries use the same ordering, so equal-cost paths are
/// reproducible regardless of the input edge order.
class DijkstraRoutePlanner<T> {
  factory DijkstraRoutePlanner({
    required Iterable<GeoNode<T>> nodes,
    required Iterable<WeightedGeoEdge> edges,
  }) {
    final Map<String, GeoNode<T>> nodesById = <String, GeoNode<T>>{};

    for (final GeoNode<T> node in nodes) {
      _validateNode(node);
      if (nodesById.containsKey(node.id)) {
        throw ArgumentError.value(node.id, 'nodes', 'Duplicate node id');
      }
      nodesById[node.id] = node;
    }

    if (nodesById.isEmpty) {
      throw ArgumentError.value(nodes, 'nodes', 'Graph cannot be empty');
    }

    final Map<String, List<_Neighbour>> adjacency = <String, List<_Neighbour>>{
      for (final String id in nodesById.keys) id: <_Neighbour>[],
    };

    for (final WeightedGeoEdge edge in edges) {
      _validateEdge(edge, nodesById);
      adjacency[edge.from]!.add(_Neighbour(edge.to, edge.weight));
      if (edge.bidirectional && edge.from != edge.to) {
        adjacency[edge.to]!.add(_Neighbour(edge.from, edge.weight));
      }
    }

    for (final List<_Neighbour> neighbours in adjacency.values) {
      neighbours.sort(_compareNeighbours);
    }

    return DijkstraRoutePlanner<T>._(
      Map<String, GeoNode<T>>.unmodifiable(nodesById),
      Map<String, List<_Neighbour>>.unmodifiable(
        adjacency.map(
          (String id, List<_Neighbour> neighbours) =>
              MapEntry<String, List<_Neighbour>>(
            id,
            List<_Neighbour>.unmodifiable(neighbours),
          ),
        ),
      ),
    );
  }

  const DijkstraRoutePlanner._(this._nodesById, this._adjacency);

  final Map<String, GeoNode<T>> _nodesById;
  final Map<String, List<_Neighbour>> _adjacency;

  /// Returns the closest reachable destination from [sourceId].
  ///
  /// Returns `null` when all destinations are unreachable. Invalid source or
  /// destination identifiers fail fast with [ArgumentError].
  DijkstraPath<T>? findNearest({
    required String sourceId,
    required Iterable<String> destinationIds,
  }) {
    if (!_nodesById.containsKey(sourceId)) {
      throw ArgumentError.value(sourceId, 'sourceId', 'Unknown source node');
    }

    final Set<String> destinations = destinationIds.toSet();
    if (destinations.isEmpty) {
      throw ArgumentError.value(
        destinationIds,
        'destinationIds',
        'At least one destination is required',
      );
    }
    for (final String destinationId in destinations) {
      if (!_nodesById.containsKey(destinationId)) {
        throw ArgumentError.value(
          destinationId,
          'destinationIds',
          'Unknown destination node',
        );
      }
    }

    final Map<String, double> distances = <String, double>{
      for (final String id in _nodesById.keys) id: double.infinity,
    };
    final Map<String, String> previous = <String, String>{};
    final _MinHeap queue = _MinHeap();

    distances[sourceId] = 0;
    queue.add(_QueueEntry(sourceId, 0));

    String? closestDestinationId;
    double? closestDistance;

    while (queue.isNotEmpty) {
      final _QueueEntry current = queue.removeFirst();
      final double knownDistance = distances[current.nodeId]!;

      if (current.distance != knownDistance) {
        continue;
      }
      if (closestDistance != null && current.distance > closestDistance) {
        break;
      }

      if (destinations.contains(current.nodeId)) {
        if (closestDestinationId == null ||
            current.distance < closestDistance! ||
            (current.distance == closestDistance &&
                current.nodeId.compareTo(closestDestinationId) < 0)) {
          closestDestinationId = current.nodeId;
          closestDistance = current.distance;
        }
      }

      for (final _Neighbour neighbour in _adjacency[current.nodeId]!) {
        final double candidateDistance = current.distance + neighbour.weight;
        if (!candidateDistance.isFinite ||
            candidateDistance >= distances[neighbour.nodeId]!) {
          continue;
        }

        distances[neighbour.nodeId] = candidateDistance;
        previous[neighbour.nodeId] = current.nodeId;
        queue.add(_QueueEntry(neighbour.nodeId, candidateDistance));
      }
    }

    if (closestDestinationId == null || closestDistance == null) {
      return null;
    }

    final List<GeoNode<T>> reversedPath = <GeoNode<T>>[];
    String cursor = closestDestinationId;
    while (true) {
      reversedPath.add(_nodesById[cursor]!);
      if (cursor == sourceId) {
        break;
      }
      final String? predecessor = previous[cursor];
      if (predecessor == null) {
        throw StateError('Could not reconstruct shortest path to $cursor');
      }
      cursor = predecessor;
    }

    return DijkstraPath<T>(
      destination: _nodesById[closestDestinationId]!,
      path: reversedPath.reversed,
      distance: closestDistance,
    );
  }

  static void _validateNode<T>(GeoNode<T> node) {
    if (node.id.trim().isEmpty) {
      throw ArgumentError.value(node.id, 'nodes', 'Node id cannot be empty');
    }
    if (!node.latitude.isFinite || node.latitude < -90 || node.latitude > 90) {
      throw ArgumentError.value(
        node.latitude,
        'nodes',
        'Latitude must be finite and between -90 and 90',
      );
    }
    if (!node.longitude.isFinite ||
        node.longitude < -180 ||
        node.longitude > 180) {
      throw ArgumentError.value(
        node.longitude,
        'nodes',
        'Longitude must be finite and between -180 and 180',
      );
    }
  }

  static void _validateEdge<T>(
    WeightedGeoEdge edge,
    Map<String, GeoNode<T>> nodesById,
  ) {
    if (!nodesById.containsKey(edge.from)) {
      throw ArgumentError.value(edge.from, 'edges', 'Unknown edge source');
    }
    if (!nodesById.containsKey(edge.to)) {
      throw ArgumentError.value(edge.to, 'edges', 'Unknown edge destination');
    }
    if (!edge.weight.isFinite || edge.weight < 0) {
      throw ArgumentError.value(
        edge.weight,
        'edges',
        'Edge weight must be finite and non-negative',
      );
    }
  }

  static int _compareNeighbours(_Neighbour left, _Neighbour right) {
    final int idComparison = left.nodeId.compareTo(right.nodeId);
    return idComparison != 0
        ? idComparison
        : left.weight.compareTo(right.weight);
  }
}

class _Neighbour {
  const _Neighbour(this.nodeId, this.weight);

  final String nodeId;
  final double weight;
}

class _QueueEntry {
  const _QueueEntry(this.nodeId, this.distance);

  final String nodeId;
  final double distance;
}

/// Small binary min-heap kept local to avoid coupling domain code to packages.
class _MinHeap {
  final List<_QueueEntry> _entries = <_QueueEntry>[];

  bool get isNotEmpty => _entries.isNotEmpty;

  void add(_QueueEntry entry) {
    _entries.add(entry);
    var index = _entries.length - 1;
    while (index > 0) {
      final int parent = (index - 1) ~/ 2;
      if (_compareQueueEntries(_entries[parent], _entries[index]) <= 0) {
        break;
      }
      _swap(parent, index);
      index = parent;
    }
  }

  _QueueEntry removeFirst() {
    if (_entries.isEmpty) {
      throw StateError('Cannot remove from an empty priority queue');
    }

    final _QueueEntry first = _entries.first;
    final _QueueEntry last = _entries.removeLast();
    if (_entries.isEmpty) {
      return first;
    }

    _entries[0] = last;
    var index = 0;
    while (true) {
      final int left = (index * 2) + 1;
      final int right = left + 1;
      var smallest = index;

      if (left < _entries.length &&
          _compareQueueEntries(_entries[left], _entries[smallest]) < 0) {
        smallest = left;
      }
      if (right < _entries.length &&
          _compareQueueEntries(_entries[right], _entries[smallest]) < 0) {
        smallest = right;
      }
      if (smallest == index) {
        break;
      }

      _swap(index, smallest);
      index = smallest;
    }

    return first;
  }

  void _swap(int left, int right) {
    final _QueueEntry value = _entries[left];
    _entries[left] = _entries[right];
    _entries[right] = value;
  }

  static int _compareQueueEntries(_QueueEntry left, _QueueEntry right) {
    final int distanceComparison = left.distance.compareTo(right.distance);
    return distanceComparison != 0
        ? distanceComparison
        : left.nodeId.compareTo(right.nodeId);
  }
}
