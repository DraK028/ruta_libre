"""API de reportes compartidos de Ruta Libre (AWS Lambda + API Gateway HTTP API).

Rutas:
  GET  /reports?lat=..&lon=..&radius=..   reportes vigentes cerca de un punto
  POST /reports                           crear un reporte
  POST /reports/{id}/confirm              "Sigue ahí"
  POST /reports/{id}/gone                 "Ya no está"

Cada teléfono manda un identificador anónimo en el encabezado X-Device-Id.
Solo se guarda su hash: sirve para limitar reportes y evitar votos repetidos,
no para identificar a nadie. Nunca se guarda ni se recibe el recorrido de la
persona: solo la ubicación del peligro.
"""
import hashlib
import json
import os
import re
import uuid
from datetime import timedelta
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

import geohash
import rules

CELL_PRECISION = 5
_DEVICE_RE = re.compile(r"^[A-Za-z0-9_-]{8,64}$")

_table = None


def table():
    global _table
    if _table is None:
        _table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
    return _table


# ---------------------------------------------------------------- utilidades

def _resp(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json; charset=utf-8"},
        "body": json.dumps(body, ensure_ascii=False),
    }


def _error(status, message):
    return _resp(status, {"error": message})


class BadRequest(Exception):
    pass


def _device_hash(event):
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    device = headers.get("x-device-id", "")
    if not _DEVICE_RE.match(device):
        raise BadRequest("Falta el identificador del dispositivo.")
    return hashlib.sha256(("ruta-libre:" + device).encode()).hexdigest()[:32]


def _body(event):
    raw = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        import base64
        raw = base64.b64decode(raw).decode()
    try:
        data = json.loads(raw)
    except ValueError:
        raise BadRequest("El cuerpo no es JSON válido.")
    if not isinstance(data, dict):
        raise BadRequest("El cuerpo debe ser un objeto JSON.")
    return data


def _coord(value, low, high, name):
    try:
        v = float(value)
    except (TypeError, ValueError):
        raise BadRequest(f"Falta o es inválida la coordenada {name}.")
    if not (low <= v <= high):
        raise BadRequest(f"La coordenada {name} está fuera de rango.")
    return v


def _public(item):
    """Lo que ve la app: mismo formato que Report.toJson() en Dart."""
    return {
        "id": item["id"],
        "type": item["type"],
        "severity": item["severity"],
        "lat": float(item["lat"]),
        "lon": float(item["lon"]),
        "createdAt": item["createdAt"],
        "lastConfirmedAt": item["lastConfirmedAt"],
        "goneVotes": len(item.get("goneVoters") or []),
        "closed": bool(item.get("closed", False)),
        "note": item.get("note", ""),
        "photoPath": None,
    }


def _lifecycle_fields(report_type, confirmed_at):
    expires = rules.expires_at(report_type, confirmed_at)
    purge = expires + rules.KEEP_AFTER_EXPIRY
    return rules.iso(expires), int(purge.timestamp())


# ---------------------------------------------------------------- rutas

def list_reports(event):
    q = event.get("queryStringParameters") or {}
    lat = _coord(q.get("lat"), -90, 90, "lat")
    lon = _coord(q.get("lon"), -180, 180, "lon")
    try:
        radius = float(q.get("radius", 1500))
    except ValueError:
        raise BadRequest("El radio no es un número.")
    radius = max(50.0, min(radius, rules.MAX_RADIUS_M))

    now = rules.now_utc()
    found = []
    for cell in geohash.neighbors(geohash.encode(lat, lon, CELL_PRECISION)):
        kwargs = {
            "IndexName": "CellIndex",
            "KeyConditionExpression": "cell = :c",
            "ExpressionAttributeValues": {":c": cell},
        }
        while True:
            page = table().query(**kwargs)
            for item in page.get("Items", []):
                if item.get("closed"):
                    continue
                if rules.parse_iso(item["expiresAt"]) <= now:
                    continue
                if rules.distance_m(lat, lon, float(item["lat"]), float(item["lon"])) > radius:
                    continue
                found.append(_public(item))
            if "LastEvaluatedKey" not in page:
                break
            kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
    return _resp(200, {"reports": found})


def _check_rate(device):
    """Máximo MAX_REPORTS_PER_HOUR reportes por dispositivo por hora."""
    now = rules.now_utc()
    key = f"rate#{device}#{now:%Y%m%d%H}"
    try:
        table().update_item(
            Key={"id": key},
            UpdateExpression="ADD hits :one SET purgeAt = if_not_exists(purgeAt, :p)",
            ConditionExpression="attribute_not_exists(hits) OR hits < :max",
            ExpressionAttributeValues={
                ":one": 1,
                ":max": rules.MAX_REPORTS_PER_HOUR,
                ":p": int((now + timedelta(hours=2)).timestamp()),
            },
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return False
        raise
    return True


def create_report(event):
    device = _device_hash(event)
    data = _body(event)
    report_type = data.get("type")
    if report_type not in rules.TYPES:
        raise BadRequest("Tipo de reporte desconocido.")
    severity = data.get("severity") or rules.TYPES[report_type][0]
    if severity not in rules.SEVERITIES:
        raise BadRequest("Gravedad desconocida.")
    lat = _coord(data.get("lat"), -90, 90, "lat")
    lon = _coord(data.get("lon"), -180, 180, "lon")
    note = str(data.get("note") or "").strip()[: rules.MAX_NOTE]

    if not _check_rate(device):
        return _error(429, "Hiciste muchos reportes en poco tiempo. Intenta más tarde.")

    now = rules.now_utc()
    expires, purge = _lifecycle_fields(report_type, now)
    item = {
        "id": uuid.uuid4().hex,
        "cell": geohash.encode(lat, lon, CELL_PRECISION),
        "type": report_type,
        "severity": severity,
        "lat": Decimal(str(round(lat, 6))),
        "lon": Decimal(str(round(lon, 6))),
        "note": note,
        "createdAt": rules.iso(now),
        "lastConfirmedAt": rules.iso(now),
        "expiresAt": expires,
        "purgeAt": purge,
        "goneVoters": [],
        "closed": False,
        "author": device,
    }
    table().put_item(Item=item)
    return _resp(201, {"report": _public(item)})


def _get(report_id):
    if not re.fullmatch(r"[0-9a-f]{32}", report_id or ""):
        return None
    item = table().get_item(Key={"id": report_id}).get("Item")
    return item if item and "cell" in item else None


def confirm_report(event, report_id):
    _device_hash(event)
    item = _get(report_id)
    if item is None:
        return _error(404, "Este reporte ya no existe.")
    now = rules.now_utc()
    expires, purge = _lifecycle_fields(item["type"], now)
    new = table().update_item(
        Key={"id": report_id},
        UpdateExpression=(
            "SET lastConfirmedAt = :n, expiresAt = :e, purgeAt = :p, "
            "goneVoters = :empty, closed = :f"
        ),
        ExpressionAttributeValues={
            ":n": rules.iso(now), ":e": expires, ":p": purge, ":empty": [], ":f": False,
        },
        ReturnValues="ALL_NEW",
    )["Attributes"]
    return _resp(200, {"report": _public(new)})


def gone_report(event, report_id, _attempt=0):
    device = _device_hash(event)
    item = _get(report_id)
    if item is None:
        return _error(404, "Este reporte ya no existe.")
    voters = list(item.get("goneVoters") or [])
    if device in voters:
        return _resp(200, {"report": _public(item), "alreadyVoted": True})
    voters.append(device)
    closed = len(voters) >= rules.VOTES_TO_CLOSE
    try:
        new = table().update_item(
            Key={"id": report_id},
            UpdateExpression="SET goneVoters = :v, closed = :c",
            # Si otro voto llegó entre la lectura y la escritura, se reintenta.
            ConditionExpression="size(goneVoters) = :n",
            ExpressionAttributeValues={
                ":v": voters, ":c": closed, ":n": len(voters) - 1,
            },
            ReturnValues="ALL_NEW",
        )["Attributes"]
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException" and _attempt < 3:
            return gone_report(event, report_id, _attempt + 1)
        raise
    return _resp(200, {"report": _public(new)})


# ---------------------------------------------------------------- entrada

def handler(event, context=None):
    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    path = event.get("rawPath") or event.get("requestContext", {}).get("http", {}).get("path", "")
    path = path.rstrip("/")
    try:
        if method == "GET" and path.endswith("/reports"):
            return list_reports(event)
        if method == "POST" and path.endswith("/reports"):
            return create_report(event)
        m = re.search(r"/reports/([^/]+)/(confirm|gone)$", path)
        if method == "POST" and m:
            report_id, action = m.groups()
            return confirm_report(event, report_id) if action == "confirm" else gone_report(event, report_id)
        return _error(404, "Ruta no encontrada.")
    except BadRequest as e:
        return _error(400, str(e))
    except ClientError:
        return _error(503, "El servidor no está disponible. Intenta en un momento.")
