import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import {
  EstimarTrayectosDto,
  PuntoRutaDto,
  TrazarRutaCompletaDto,
  TrazarRutaDto,
} from './dto';

type OsrmRoute = {
  duration?: unknown;
  distance?: unknown;
  geometry?: {
    coordinates?: unknown;
  };
};

type OsrmResponse = {
  code?: unknown;
  durations?: unknown;
  distances?: unknown;
  routes?: unknown[];
  trips?: unknown[];
};

type RouteResult = {
  points: Array<[number, number]>;
  durationMs: number;
  distanceMeters: number;
};

type CachedRoute = {
  value: RouteResult;
  expiresAt: number;
};

@Injectable()
export class RoutingService {
  private static readonly maxCachedRoutes = 64;
  private static readonly cacheTtlMs = 2 * 60 * 1000;
  private static readonly maxTripDistanceMeters = 100_000;
  private static readonly maxRoadDistanceMeters = 250_000;
  private static readonly maxRoutePoints = 6000;
  private static readonly maxResponseBytes = 2_000_000;

  private readonly baseUrl: string;
  private readonly timeoutMs: number;
  private readonly routeCache = new Map<string, CachedRoute>();

  constructor(config: ConfigService) {
    this.baseUrl = config
      .get<string>('OSRM_BASE_URL', 'https://router.project-osrm.org')
      .replace(/\/+$/, '');
    this.timeoutMs = config.get<number>('OSRM_TIMEOUT_MS', 9000);
  }

  async estimateTrips(dto: EstimarTrayectosDto) {
    this.assertNearby(dto.origin, dto.destinations);
    const points = [dto.origin, ...dto.destinations];
    const destinations = dto.destinations
      .map((_, index) => String(index + 1))
      .join(';');
    const url = new URL(
      `${this.baseUrl}/table/v1/driving/${this.coordinates(points)}`,
    );
    url.searchParams.set('sources', '0');
    url.searchParams.set('destinations', destinations);
    url.searchParams.set('annotations', 'duration,distance');

    const json = await this.getJson(url);
    if (json === null) {
      return {
        providerAvailable: false,
        estimates: dto.destinations.map(() => null),
      };
    }
    if (json.code !== 'Ok') {
      return {
        providerAvailable: true,
        estimates: dto.destinations.map(() => null),
      };
    }
    const durations = this.firstMatrixRow(json?.durations);
    const distances = this.firstMatrixRow(json?.distances);
    const estimates = dto.destinations.map((_, index) => {
      const durationSeconds = this.nonNegativeFiniteNumber(durations[index]);
      const distanceMeters = this.nonNegativeFiniteNumber(distances[index]);
      if (durationSeconds === null || distanceMeters === null) {
        return null;
      }
      return {
        durationMs: Math.round(durationSeconds * 1000),
        distanceMeters,
      };
    });
    return { providerAvailable: true, estimates };
  }

  async traceRoute(dto: TrazarRutaDto) {
    this.assertNearby(dto.origin, [dto.destination]);
    return { route: await this.tracePoints([dto.origin, dto.destination]) };
  }

  async traceRouteThrough(dto: TrazarRutaCompletaDto) {
    this.assertNearby(dto.origin, dto.destinations);
    if (dto.destinations.length === 1) {
      return {
        route: await this.tracePoints([dto.origin, dto.destinations[0]]),
      };
    }

    const destinations = this.withFarthestDestinationLast(
      dto.origin,
      dto.destinations,
    );
    return {
      route: await this.tracePoints([dto.origin, ...destinations], true),
    };
  }

  private async tracePoints(requestedPoints: PuntoRutaDto[], optimize = false) {
    const cacheKey = `${optimize ? 'trip' : 'route'}:${requestedPoints
      .map((point) => this.coordinate(point))
      .join('>')}`;
    const cached = this.routeCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      this.routeCache.delete(cacheKey);
      this.routeCache.set(cacheKey, cached);
      return cached.value;
    }
    if (cached) {
      this.routeCache.delete(cacheKey);
    }

    const service = optimize ? 'trip' : 'route';
    const url = new URL(
      `${this.baseUrl}/${service}/v1/driving/${this.coordinates(requestedPoints)}`,
    );
    url.searchParams.set('overview', 'simplified');
    url.searchParams.set('geometries', 'geojson');
    url.searchParams.set('steps', 'false');
    if (optimize) {
      url.searchParams.set('source', 'first');
      url.searchParams.set('destination', 'last');
      url.searchParams.set('roundtrip', 'false');
    }

    const json = await this.getJson(url);
    const routes = optimize ? (json?.trips ?? []) : (json?.routes ?? []);
    const rawRoute = routes[0];
    if (json?.code !== 'Ok' || !this.isRecord(rawRoute)) {
      return null;
    }

    const route = rawRoute as OsrmRoute;
    const rawCoordinates = Array.isArray(route.geometry?.coordinates)
      ? route.geometry.coordinates
      : [];
    if (rawCoordinates.length > RoutingService.maxRoutePoints) {
      return null;
    }
    const points = rawCoordinates
      .filter((pair): pair is [number, number] => this.isCoordinatePair(pair))
      .map<[number, number]>((pair) => [pair[1], pair[0]]);
    const durationSeconds = this.nonNegativeFiniteNumber(route.duration);
    const distanceMeters = this.nonNegativeFiniteNumber(route.distance);
    if (
      points.length < 2 ||
      durationSeconds === null ||
      distanceMeters === null ||
      distanceMeters > RoutingService.maxRoadDistanceMeters
    ) {
      return null;
    }

    const result: RouteResult = {
      points,
      durationMs: Math.round(durationSeconds * 1000),
      distanceMeters,
    };
    this.routeCache.set(cacheKey, {
      value: result,
      expiresAt: Date.now() + RoutingService.cacheTtlMs,
    });
    if (this.routeCache.size > RoutingService.maxCachedRoutes) {
      const oldest = this.routeCache.keys().next().value;
      if (oldest) {
        this.routeCache.delete(oldest);
      }
    }
    return result;
  }

  private async getJson(url: URL): Promise<OsrmResponse | null> {
    try {
      const response = await fetch(url, {
        headers: { accept: 'application/json' },
        signal: AbortSignal.timeout(this.timeoutMs),
      });
      if (!response.ok) {
        return null;
      }
      const raw = await this.readLimitedBody(response);
      if (raw === null) {
        return null;
      }
      const value: unknown = JSON.parse(raw);
      if (!this.isRecord(value)) {
        return null;
      }
      return {
        code: value.code,
        durations: value.durations,
        distances: value.distances,
        routes: Array.isArray(value.routes)
          ? Array.from<unknown>(value.routes)
          : undefined,
        trips: Array.isArray(value.trips)
          ? Array.from<unknown>(value.trips)
          : undefined,
      };
    } catch {
      return null;
    }
  }

  private coordinates(points: PuntoRutaDto[]) {
    return points.map((point) => this.coordinate(point)).join(';');
  }

  private coordinate(point: PuntoRutaDto) {
    return `${point.longitude.toFixed(6)},${point.latitude.toFixed(6)}`;
  }

  private assertNearby(origin: PuntoRutaDto, destinations: PuntoRutaDto[]) {
    const outsideServiceArea = destinations.some(
      (destination) =>
        this.distanceMeters(origin, destination) >
        RoutingService.maxTripDistanceMeters,
    );
    if (outsideServiceArea) {
      throw new BadRequestException(
        'El trayecto solicitado excede la distancia máxima permitida',
      );
    }
  }

  private withFarthestDestinationLast(
    origin: PuntoRutaDto,
    destinations: PuntoRutaDto[],
  ) {
    let farthestIndex = 0;
    let farthestDistance = -1;
    destinations.forEach((destination, index) => {
      const distance = this.distanceMeters(origin, destination);
      if (distance > farthestDistance) {
        farthestIndex = index;
        farthestDistance = distance;
      }
    });
    return [
      ...destinations.slice(0, farthestIndex),
      ...destinations.slice(farthestIndex + 1),
      destinations[farthestIndex],
    ];
  }

  private distanceMeters(left: PuntoRutaDto, right: PuntoRutaDto) {
    const toRadians = Math.PI / 180;
    const latitudeDelta = (right.latitude - left.latitude) * toRadians;
    const longitudeDelta = (right.longitude - left.longitude) * toRadians;
    const leftLatitude = left.latitude * toRadians;
    const rightLatitude = right.latitude * toRadians;
    const haversine =
      Math.sin(latitudeDelta / 2) ** 2 +
      Math.cos(leftLatitude) *
        Math.cos(rightLatitude) *
        Math.sin(longitudeDelta / 2) ** 2;
    return 2 * 6_371_000 * Math.asin(Math.min(1, Math.sqrt(haversine)));
  }

  private firstMatrixRow(value: unknown): unknown[] {
    if (!Array.isArray(value) || !Array.isArray(value[0])) {
      return [];
    }
    return value[0] as unknown[];
  }

  private finiteNumber(value: unknown) {
    return typeof value === 'number' && Number.isFinite(value) ? value : null;
  }

  private nonNegativeFiniteNumber(value: unknown) {
    const number = this.finiteNumber(value);
    return number !== null && number >= 0 ? number : null;
  }

  private isCoordinatePair(value: unknown): value is [number, number] {
    if (!Array.isArray(value) || value.length < 2) {
      return false;
    }
    const longitude = this.finiteNumber(value[0]);
    const latitude = this.finiteNumber(value[1]);
    return (
      longitude !== null &&
      latitude !== null &&
      longitude >= -180 &&
      longitude <= 180 &&
      latitude >= -90 &&
      latitude <= 90
    );
  }

  private async readLimitedBody(response: Response) {
    const declaredLength = Number(response.headers.get('content-length'));
    if (
      Number.isFinite(declaredLength) &&
      declaredLength > RoutingService.maxResponseBytes
    ) {
      await response.body?.cancel();
      return null;
    }
    const reader = response.body?.getReader();
    if (!reader) {
      return '';
    }
    const decoder = new TextDecoder();
    const chunks: string[] = [];
    let totalBytes = 0;
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      totalBytes += value.byteLength;
      if (totalBytes > RoutingService.maxResponseBytes) {
        await reader.cancel();
        return null;
      }
      chunks.push(decoder.decode(value, { stream: true }));
    }
    chunks.push(decoder.decode());
    return chunks.join('');
  }

  private isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === 'object' && value !== null && !Array.isArray(value);
  }
}
