"""Mesh-edge shortest paths for authored evidence reveal; no screen-space fills."""
import heapq
import math


def surface_distances(vertices, edges, seed, permitted):
    """Return metres along permitted mesh edges; unreachable vertices stay infinite.

    Coincident vertices are joined at 1e-5 m precision to cross split UV seams.
    Each call belongs to exactly one authored mesh: separate panels never join.
    """
    if len(permitted) != len(vertices):
        raise ValueError('One permission flag is required per vertex')
    if len(seed) != 3 or not all(math.isfinite(c) for c in seed):
        raise ValueError('Seed must be finite xyz')
    if any(len(v) != 3 or not all(math.isfinite(c) for c in v) for v in vertices):
        raise ValueError('Vertices must be finite xyz')
    adj = [{} for _ in vertices]
    buckets = {}
    for i, v in enumerate(vertices):
        if permitted[i]:
            buckets.setdefault(tuple(round(c, 5) for c in v), []).append(i)
    for group in buckets.values():
        for i in group[1:]:
            adj[group[0]][i] = 0
            adj[i][group[0]] = 0
    for a, b in edges:
        if not (0 <= a < len(vertices) and 0 <= b < len(vertices)):
            raise ValueError('Edge references a missing vertex')
        if permitted[a] and permitted[b]:
            d = math.dist(vertices[a], vertices[b])
            adj[a][b] = d
            adj[b][a] = d
    distances = [math.inf] * len(vertices)
    candidates = [i for i, p in enumerate(permitted) if p]
    if not candidates:
        return distances
    # Index tie-break makes duplicate/equidistant seeds deterministic.
    first = min(candidates, key=lambda i: (math.dist(vertices[i], seed), i))
    distances[first] = 0
    queue = [(0, first)]
    while queue:
        distance, i = heapq.heappop(queue)
        if distance != distances[i]:
            continue
        for j, weight in adj[i].items():
            next_distance = distance + weight
            if next_distance < distances[j]:
                distances[j] = next_distance
                heapq.heappush(queue, (next_distance, j))
    return distances
