"""Pruebas de la API de reportes con DynamoDB simulado (moto)."""
import json
import os
import sys
from datetime import timedelta

import boto3
import pytest
from moto import mock_aws

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

import app  # noqa: E402
import geohash  # noqa: E402
import rules  # noqa: E402

UPIICSA = (19.3958, -99.0912)
DEVICE_A = "dispositivo-aaaaaaaa"
DEVICE_B = "dispositivo-bbbbbbbb"


@pytest.fixture(autouse=True)
def dynamo(monkeypatch):
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "test")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "test")
    monkeypatch.setenv("TABLE_NAME", "reportes")
    with mock_aws():
        ddb = boto3.resource("dynamodb", region_name="us-east-1")
        ddb.create_table(
            TableName="reportes",
            BillingMode="PAY_PER_REQUEST",
            AttributeDefinitions=[
                {"AttributeName": "id", "AttributeType": "S"},
                {"AttributeName": "cell", "AttributeType": "S"},
                {"AttributeName": "lastConfirmedAt", "AttributeType": "S"},
            ],
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            GlobalSecondaryIndexes=[{
                "IndexName": "CellIndex",
                "KeySchema": [
                    {"AttributeName": "cell", "KeyType": "HASH"},
                    {"AttributeName": "lastConfirmedAt", "KeyType": "RANGE"},
                ],
                "Projection": {"ProjectionType": "ALL"},
            }],
        )
        app._table = None
        yield
        app._table = None


def call(method, path, body=None, query=None, device=DEVICE_A):
    event = {
        "rawPath": "/piloto" + path,
        "requestContext": {"http": {"method": method, "path": "/piloto" + path}},
        "headers": {"X-Device-Id": device} if device else {},
        "queryStringParameters": query,
        "body": json.dumps(body) if body is not None else None,
    }
    res = app.handler(event)
    return res["statusCode"], json.loads(res["body"])


def create(lat=UPIICSA[0], lon=UPIICSA[1], **kw):
    body = {"type": "blockedRamp", "lat": lat, "lon": lon, **kw}
    return call("POST", "/reports", body)


def near(lat=UPIICSA[0], lon=UPIICSA[1], radius=1500, device=DEVICE_A):
    return call("GET", "/reports", query={"lat": str(lat), "lon": str(lon), "radius": str(radius)}, device=device)


# ------------------------------------------------------------------ geohash

def test_geohash_conocido():
    # Valor de referencia: (57.64911, 10.40744) -> u4pruydqqvj
    assert geohash.encode(57.64911, 10.40744, 11) == "u4pruydqqvj"


def test_vecinos_cubren_la_celda_y_sus_alrededores():
    cell = geohash.encode(*UPIICSA, 5)
    vecinos = geohash.neighbors(cell)
    assert len(vecinos) == 9 and cell in vecinos
    # Un punto 3 km al norte cae en alguna de las 9 celdas.
    assert geohash.encode(UPIICSA[0] + 0.027, UPIICSA[1], 5) in vecinos


# ------------------------------------------------------------------ API

def test_crear_y_consultar():
    status, body = create(note="Coche gris")
    assert status == 201
    r = body["report"]
    assert r["type"] == "blockedRamp" and r["severity"] == "high"
    assert r["note"] == "Coche gris" and r["goneVotes"] == 0 and r["closed"] is False

    status, body = near(device=DEVICE_B)  # otro teléfono lo ve
    assert status == 200
    assert [x["id"] for x in body["reports"]] == [r["id"]]


def test_no_devuelve_reportes_lejanos():
    create(lat=UPIICSA[0] + 0.1)  # ~11 km al norte
    _, body = near()
    assert body["reports"] == []


def test_validacion():
    assert call("POST", "/reports", {"type": "x", "lat": 1, "lon": 1})[0] == 400
    assert call("POST", "/reports", {"type": "other", "lat": 100, "lon": 1})[0] == 400
    assert call("POST", "/reports", {"type": "other", "lat": 1, "lon": 1, "severity": "mucha"})[0] == 400
    assert call("POST", "/reports", {"type": "other", "lat": 1, "lon": 1}, device=None)[0] == 400
    assert call("GET", "/reports", query={"lat": "x", "lon": "1"})[0] == 400


def test_nota_se_recorta():
    _, body = create(note="a" * 500)
    assert len(body["report"]["note"]) == rules.MAX_NOTE


def test_dos_votos_de_distintos_telefonos_lo_cierran():
    rid = create()[1]["report"]["id"]
    s, b = call("POST", f"/reports/{rid}/gone", {})
    assert s == 200 and b["report"]["goneVotes"] == 1 and not b["report"]["closed"]
    # El mismo teléfono no vota dos veces.
    s, b = call("POST", f"/reports/{rid}/gone", {})
    assert b.get("alreadyVoted") is True and b["report"]["goneVotes"] == 1
    s, b = call("POST", f"/reports/{rid}/gone", {}, device=DEVICE_B)
    assert b["report"]["closed"] is True
    assert near()[1]["reports"] == []


def test_sigue_ahi_reinicia_votos_y_caducidad():
    rid = create()[1]["report"]["id"]
    call("POST", f"/reports/{rid}/gone", {})
    s, b = call("POST", f"/reports/{rid}/confirm", {}, device=DEVICE_B)
    assert s == 200 and b["report"]["goneVotes"] == 0 and b["report"]["closed"] is False


def test_reporte_caducado_no_se_muestra(monkeypatch):
    create()
    future = rules.now_utc() + timedelta(hours=7)  # rampa bloqueada: 6 h
    monkeypatch.setattr(rules, "now_utc", lambda: future)
    assert near()[1]["reports"] == []


def test_inexistente():
    assert call("POST", "/reports/" + "0" * 32 + "/confirm", {})[0] == 404
    assert call("POST", "/reports/no-es-id/gone", {})[0] == 404


def test_limite_de_reportes_por_hora(monkeypatch):
    monkeypatch.setattr(rules, "MAX_REPORTS_PER_HOUR", 3)
    assert [create()[0] for _ in range(4)] == [201, 201, 201, 429]
    # Otro teléfono no se ve afectado.
    assert call("POST", "/reports", {"type": "other", "lat": 1, "lon": 1}, device=DEVICE_B)[0] == 201


def test_ruta_desconocida():
    assert call("GET", "/otra")[0] == 404


def test_ttl_coinciden_con_la_app():
    # Mismos tiempos de vida que lib/models/report.dart.
    dart = open(os.path.join(os.path.dirname(__file__), "..", "..", "lib", "models", "report.dart")).read()
    for name, (severity, ttl) in rules.TYPES.items():
        assert name in dart
        line = next(l for l in dart.splitlines() if l.strip().startswith(name + "("))
        assert f"Severity.{severity}" in line
        hours = ttl.total_seconds() / 3600
        assert (f"hours: {int(hours)}" in line) or (f"days: {int(hours // 24)}" in line), line
