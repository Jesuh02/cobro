import 'package:cobro_app/features/routes/domain/dijkstra_route_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DijkstraRoutePlanner', () {
    test('returns the closest destination with its shortest path', () {
      final DijkstraRoutePlanner<String> planner = DijkstraRoutePlanner<String>(
        nodes: const <GeoNode<String>>[
          GeoNode<String>(
            id: 'origin',
            latitude: 11.5449,
            longitude: -72.9072,
            value: 'Current location',
          ),
          GeoNode<String>(
            id: 'crossing',
            latitude: 11.5450,
            longitude: -72.9060,
            value: 'Crossing',
          ),
          GeoNode<String>(
            id: 'client-near',
            latitude: 11.5460,
            longitude: -72.9050,
            value: 'Near client',
          ),
          GeoNode<String>(
            id: 'client-far',
            latitude: 11.5500,
            longitude: -72.9000,
            value: 'Far client',
          ),
        ],
        edges: const <WeightedGeoEdge>[
          WeightedGeoEdge(from: 'origin', to: 'client-near', weight: 8),
          WeightedGeoEdge(from: 'origin', to: 'crossing', weight: 2),
          WeightedGeoEdge(from: 'crossing', to: 'client-near', weight: 3),
          WeightedGeoEdge(from: 'origin', to: 'client-far', weight: 9),
        ],
      );

      final DijkstraPath<String>? result = planner.findNearest(
        sourceId: 'origin',
        destinationIds: const <String>['client-near', 'client-far'],
      );

      expect(result, isNotNull);
      expect(result!.destination.id, 'client-near');
      expect(result.destination.value, 'Near client');
      expect(result.distance, 5);
      expect(
        result.path.map((GeoNode<String> node) => node.id),
        <String>['origin', 'crossing', 'client-near'],
      );
    });

    test('returns null when every destination is disconnected', () {
      final DijkstraRoutePlanner<void> planner = DijkstraRoutePlanner<void>(
        nodes: const <GeoNode<void>>[
          GeoNode<void>(
            id: 'origin',
            latitude: 0,
            longitude: 0,
            value: null,
          ),
          GeoNode<void>(
            id: 'reachable',
            latitude: 1,
            longitude: 1,
            value: null,
          ),
          GeoNode<void>(
            id: 'disconnected-client',
            latitude: 2,
            longitude: 2,
            value: null,
          ),
        ],
        edges: const <WeightedGeoEdge>[
          WeightedGeoEdge(from: 'origin', to: 'reachable', weight: 1),
        ],
      );

      expect(
        planner.findNearest(
          sourceId: 'origin',
          destinationIds: const <String>['disconnected-client'],
        ),
        isNull,
      );
    });

    test('uses destination id as a deterministic equal-distance tie-breaker',
        () {
      final DijkstraRoutePlanner<void> planner = DijkstraRoutePlanner<void>(
        nodes: const <GeoNode<void>>[
          GeoNode<void>(
            id: 'origin',
            latitude: 0,
            longitude: 0,
            value: null,
          ),
          GeoNode<void>(
            id: 'z-crossing',
            latitude: 1,
            longitude: 0,
            value: null,
          ),
          GeoNode<void>(
            id: 'client-a',
            latitude: 2,
            longitude: 0,
            value: null,
          ),
          GeoNode<void>(
            id: 'client-b',
            latitude: 0,
            longitude: 2,
            value: null,
          ),
        ],
        edges: const <WeightedGeoEdge>[
          // client-b enters the queue first at distance 5. client-a is only
          // discovered later through a zero-cost edge at that same distance.
          WeightedGeoEdge(from: 'origin', to: 'client-b', weight: 5),
          WeightedGeoEdge(from: 'z-crossing', to: 'client-a', weight: 0),
          WeightedGeoEdge(from: 'origin', to: 'z-crossing', weight: 5),
        ],
      );

      final DijkstraPath<void>? result = planner.findNearest(
        sourceId: 'origin',
        destinationIds: const <String>['client-b', 'client-a'],
      );

      expect(result, isNotNull);
      expect(result!.destination.id, 'client-a');
      expect(result.distance, 5);
      expect(
        result.path.map((GeoNode<void> node) => node.id),
        <String>['origin', 'z-crossing', 'client-a'],
      );
    });

    test('resolves equal-cost paths reproducibly', () {
      final DijkstraRoutePlanner<void> planner = DijkstraRoutePlanner<void>(
        nodes: const <GeoNode<void>>[
          GeoNode<void>(
            id: 'origin',
            latitude: 0,
            longitude: 0,
            value: null,
          ),
          GeoNode<void>(
            id: 'crossing-a',
            latitude: 1,
            longitude: 0,
            value: null,
          ),
          GeoNode<void>(
            id: 'crossing-b',
            latitude: 0,
            longitude: 1,
            value: null,
          ),
          GeoNode<void>(
            id: 'client',
            latitude: 1,
            longitude: 1,
            value: null,
          ),
        ],
        edges: const <WeightedGeoEdge>[
          WeightedGeoEdge(from: 'crossing-b', to: 'client', weight: 1),
          WeightedGeoEdge(from: 'origin', to: 'crossing-b', weight: 1),
          WeightedGeoEdge(from: 'crossing-a', to: 'client', weight: 1),
          WeightedGeoEdge(from: 'origin', to: 'crossing-a', weight: 1),
        ],
      );

      final DijkstraPath<void>? result = planner.findNearest(
        sourceId: 'origin',
        destinationIds: const <String>['client'],
      );

      expect(
        result!.path.map((GeoNode<void> node) => node.id),
        <String>['origin', 'crossing-a', 'client'],
      );
    });

    group('validation', () {
      test('rejects negative or non-finite edge weights', () {
        const List<GeoNode<void>> nodes = <GeoNode<void>>[
          GeoNode<void>(
            id: 'origin',
            latitude: 0,
            longitude: 0,
            value: null,
          ),
          GeoNode<void>(
            id: 'client',
            latitude: 1,
            longitude: 1,
            value: null,
          ),
        ];

        expect(
          () => DijkstraRoutePlanner<void>(
            nodes: nodes,
            edges: const <WeightedGeoEdge>[
              WeightedGeoEdge(from: 'origin', to: 'client', weight: -1),
            ],
          ),
          throwsArgumentError,
        );
        expect(
          () => DijkstraRoutePlanner<void>(
            nodes: nodes,
            edges: const <WeightedGeoEdge>[
              WeightedGeoEdge(
                from: 'origin',
                to: 'client',
                weight: double.infinity,
              ),
            ],
          ),
          throwsArgumentError,
        );
      });

      test('rejects invalid coordinates and unknown edge nodes', () {
        expect(
          () => DijkstraRoutePlanner<void>(
            nodes: const <GeoNode<void>>[
              GeoNode<void>(
                id: 'invalid',
                latitude: 91,
                longitude: 0,
                value: null,
              ),
            ],
            edges: const <WeightedGeoEdge>[],
          ),
          throwsArgumentError,
        );

        expect(
          () => DijkstraRoutePlanner<void>(
            nodes: const <GeoNode<void>>[
              GeoNode<void>(
                id: 'origin',
                latitude: 0,
                longitude: 0,
                value: null,
              ),
            ],
            edges: const <WeightedGeoEdge>[
              WeightedGeoEdge(from: 'origin', to: 'missing', weight: 1),
            ],
          ),
          throwsArgumentError,
        );
      });

      test('rejects unknown sources, destinations, and empty target sets', () {
        final DijkstraRoutePlanner<void> planner = DijkstraRoutePlanner<void>(
          nodes: const <GeoNode<void>>[
            GeoNode<void>(
              id: 'origin',
              latitude: 0,
              longitude: 0,
              value: null,
            ),
          ],
          edges: const <WeightedGeoEdge>[],
        );

        expect(
          () => planner.findNearest(
            sourceId: 'missing',
            destinationIds: const <String>['origin'],
          ),
          throwsArgumentError,
        );
        expect(
          () => planner.findNearest(
            sourceId: 'origin',
            destinationIds: const <String>['missing'],
          ),
          throwsArgumentError,
        );
        expect(
          () => planner.findNearest(
            sourceId: 'origin',
            destinationIds: const <String>[],
          ),
          throwsArgumentError,
        );
      });
    });
  });
}
