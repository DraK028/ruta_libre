"""Geohash mínimo (codificar y vecinos) sin dependencias.

Los reportes se agrupan por celda de geohash de 5 caracteres (~4.9 km × 4.9 km)
para consultarlos por zona en DynamoDB: la celda del punto y sus 8 vecinas
cubren cualquier radio de hasta ~2.4 km.
"""

_BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz"


def encode(lat: float, lon: float, precision: int = 5) -> str:
    lat_rng = [-90.0, 90.0]
    lon_rng = [-180.0, 180.0]
    out, bit, ch, even = [], 0, 0, True
    while len(out) < precision:
        rng, val = (lon_rng, lon) if even else (lat_rng, lat)
        mid = (rng[0] + rng[1]) / 2
        if val >= mid:
            ch = (ch << 1) | 1
            rng[0] = mid
        else:
            ch <<= 1
            rng[1] = mid
        even = not even
        bit += 1
        if bit == 5:
            out.append(_BASE32[ch])
            bit, ch = 0, 0
    return "".join(out)


def _bounds(cell: str):
    lat_rng = [-90.0, 90.0]
    lon_rng = [-180.0, 180.0]
    even = True
    for c in cell:
        v = _BASE32.index(c)
        for i in range(4, -1, -1):
            rng = lon_rng if even else lat_rng
            mid = (rng[0] + rng[1]) / 2
            if (v >> i) & 1:
                rng[0] = mid
            else:
                rng[1] = mid
            even = not even
    return lat_rng, lon_rng


def neighbors(cell: str) -> list[str]:
    """La celda y sus 8 vecinas."""
    (s, n), (w, e) = _bounds(cell)
    lat_c, lon_c = (s + n) / 2, (w + e) / 2
    dlat, dlon = n - s, e - w
    out = []
    for i in (-1, 0, 1):
        for j in (-1, 0, 1):
            lat = max(-89.999999, min(89.999999, lat_c + i * dlat))
            lon = ((lon_c + j * dlon + 180) % 360) - 180
            g = encode(lat, lon, len(cell))
            if g not in out:
                out.append(g)
    return out
