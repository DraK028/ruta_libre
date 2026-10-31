"""Reglas de los reportes: deben coincidir con lib/models/report.dart."""
import math
from datetime import datetime, timedelta, timezone

# tipo -> (gravedad por defecto, tiempo de vida)
TYPES = {
    "blockedRamp": ("high", timedelta(hours=6)),
    "openDrain": ("high", timedelta(days=3)),
    "brokenSidewalk": ("medium", timedelta(days=30)),
    "construction": ("medium", timedelta(days=14)),
    "noRamp": ("medium", timedelta(days=90)),
    "elevatorOut": ("high", timedelta(days=2)),
    "flooding": ("high", timedelta(days=1)),
    "other": ("medium", timedelta(days=7)),
}
SEVERITIES = {"low", "medium", "high"}

VOTES_TO_CLOSE = 2
KEEP_AFTER_EXPIRY = timedelta(days=30)
MAX_NOTE = 140
MAX_RADIUS_M = 2400
MAX_REPORTS_PER_HOUR = 20


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def parse_iso(s: str) -> datetime:
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def expires_at(report_type: str, last_confirmed: datetime) -> datetime:
    return last_confirmed + TYPES[report_type][1]


def distance_m(lat1, lon1, lat2, lon2) -> float:
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))
