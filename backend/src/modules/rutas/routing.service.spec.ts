import { ConfigService } from '@nestjs/config';

import { RoutingService } from './routing.service';

describe('RoutingService', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('normalizes OSRM matrix estimates for the Flutter client', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(
      jsonResponse({
        code: 'Ok',
        durations: [[120.5, null]],
        distances: [[1800.25, null]],
      }),
    );
    const service = createService();

    const result = await service.estimateTrips({
      origin: { latitude: 11.54, longitude: -72.9 },
      destinations: [
        { latitude: 11.55, longitude: -72.91 },
        { latitude: 11.56, longitude: -72.92 },
      ],
    });

    expect(result.estimates).toEqual([
      { durationMs: 120_500, distanceMeters: 1800.25 },
      null,
    ]);
    expect(result.providerAvailable).toBe(true);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const requestUrl = fetchMock.mock.calls[0][0];
    expect(requestUrl).toBeInstanceOf(URL);
    if (!(requestUrl instanceof URL)) {
      throw new Error('Expected a URL request');
    }
    expect(requestUrl.pathname).toContain('/table/v1/driving/');
  });

  it('distinguishes a provider outage from an unreachable destination', async () => {
    jest.spyOn(global, 'fetch').mockRejectedValue(new Error('offline'));
    const service = createService();

    const result = await service.estimateTrips({
      origin: { latitude: 11.54, longitude: -72.9 },
      destinations: [{ latitude: 11.55, longitude: -72.91 }],
    });

    expect(result).toEqual({
      providerAvailable: false,
      estimates: [null],
    });
  });

  it('converts GeoJSON longitude-latitude pairs and caches the route', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(
      jsonResponse({
        code: 'Ok',
        routes: [
          {
            duration: 95,
            distance: 1400,
            geometry: {
              coordinates: [
                [-72.9, 11.54],
                [-72.91, 11.55],
              ],
            },
          },
        ],
      }),
    );
    const service = createService();
    const request = {
      origin: { latitude: 11.54, longitude: -72.9 },
      destination: { latitude: 11.55, longitude: -72.91 },
    };

    const first = await service.traceRoute(request);
    const second = await service.traceRoute(request);

    expect(first).toEqual({
      route: {
        points: [
          [11.54, -72.9],
          [11.55, -72.91],
        ],
        durationMs: 95_000,
        distanceMeters: 1400,
      },
    });
    expect(second).toEqual(first);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const requestUrl = fetchMock.mock.calls[0][0];
    expect(requestUrl).toBeInstanceOf(URL);
    if (requestUrl instanceof URL) {
      expect(requestUrl.searchParams.get('overview')).toBe('simplified');
    }
  });

  it('optimizes one continuous trip through every collection stop', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(
      jsonResponse({
        code: 'Ok',
        trips: [
          {
            duration: 420,
            distance: 6200,
            geometry: {
              coordinates: [
                [-72.9, 11.54],
                [-72.91, 11.55],
                [-72.92, 11.56],
              ],
            },
          },
        ],
      }),
    );
    const service = createService();

    const result = await service.traceRouteThrough({
      origin: { latitude: 11.54, longitude: -72.9 },
      destinations: [
        { latitude: 11.55, longitude: -72.91 },
        { latitude: 11.56, longitude: -72.92 },
      ],
    });

    expect(result.route?.points).toHaveLength(3);
    const requestUrl = fetchMock.mock.calls[0][0];
    expect(requestUrl).toBeInstanceOf(URL);
    if (requestUrl instanceof URL) {
      expect(requestUrl.pathname).toContain('/trip/v1/driving/');
      expect(requestUrl.searchParams.get('source')).toBe('first');
      expect(requestUrl.searchParams.get('destination')).toBe('last');
      expect(requestUrl.searchParams.get('roundtrip')).toBe('false');
    }
  });

  it('returns a safe null route when the provider is unavailable', async () => {
    jest.spyOn(global, 'fetch').mockRejectedValue(new Error('offline'));
    const service = createService();

    await expect(
      service.traceRoute({
        origin: { latitude: 11.54, longitude: -72.9 },
        destination: { latitude: 11.55, longitude: -72.91 },
      }),
    ).resolves.toEqual({ route: null });
  });

  it('rejects requests outside the collection service radius', async () => {
    const fetchMock = jest.spyOn(global, 'fetch');
    const service = createService();

    await expect(
      service.traceRoute({
        origin: { latitude: 11.54, longitude: -72.9 },
        destination: { latitude: 4.71, longitude: -74.07 },
      }),
    ).rejects.toThrow('excede la distancia máxima');
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('rejects corrupt route metrics and out-of-range geometry', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(
      jsonResponse({
        code: 'Ok',
        routes: [
          {
            duration: -10,
            distance: -1,
            geometry: {
              coordinates: [
                [-72.9, 111.54],
                [-72.91, 11.55],
              ],
            },
          },
        ],
      }),
    );
    const service = createService();

    await expect(
      service.traceRoute({
        origin: { latitude: 11.54, longitude: -72.9 },
        destination: { latitude: 11.55, longitude: -72.91 },
      }),
    ).resolves.toEqual({ route: null });
  });
});

function createService() {
  return new RoutingService(
    new ConfigService({
      OSRM_BASE_URL: 'https://routing.test',
      OSRM_TIMEOUT_MS: 1000,
    }),
  );
}

function jsonResponse(body: unknown) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });
}
