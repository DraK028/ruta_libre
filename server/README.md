# Servidor de reportes de Ruta Libre

API para compartir los reportes de peligros entre todas las personas que usan la app.

```
App ──HTTPS──> API Gateway (HTTP API) ──> Lambda (Python 3.12) ──> DynamoDB
```

| Ruta | Qué hace |
| --- | --- |
| `GET /reports?lat=&lon=&radius=` | Reportes vigentes a `radius` metros o menos (máx. 2,400) |
| `POST /reports` | Crea un reporte: `type`, `severity`, `lat`, `lon`, `note` |
| `POST /reports/{id}/confirm` | «Sigue ahí»: reinicia la caducidad y los votos |
| `POST /reports/{id}/gone` | «Ya no está»: dos teléfonos distintos lo cierran |

Todas las peticiones llevan el encabezado `X-Device-Id` (código anónimo aleatorio de cada instalación). El servidor guarda solo su hash y lo usa para limitar a 20 reportes por hora y evitar votos repetidos.

**Privacidad:** no se recibe ni se guarda el recorrido de nadie. Se guarda la ubicación del peligro, su tipo, gravedad y nota. Las fotos no se suben. DynamoDB borra cada reporte 30 días después de caducar (TTL).

**Costo:** para el piloto cabe en la capa gratuita de AWS (Lambda, API Gateway y DynamoDB bajo demanda). Límite de 10 peticiones por segundo para evitar abusos.

## Desplegar

Requisitos: cuenta de AWS, [AWS CLI](https://aws.amazon.com/cli/) y [SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html).

```bash
aws configure          # una vez, con las llaves de un usuario IAM tuyo
cd server
sam deploy             # usa samconfig.toml (pila ruta-libre-reportes, us-east-1)
```

Al terminar, la salida `ApiUrl` es la URL que necesita la app. En Windows, `setup\desplegar_servidor.bat` hace todo y guarda la URL en `setup\servidor_url.txt`, que `setup\generar_apk.bat` usa al compilar.

En GitHub: agrega la variable de repositorio `REPORTS_API_URL` (Settings → Secrets and variables → Actions → Variables) para que el APK y la web de la integración continua usen el servidor. Opcionalmente, con los secretos `AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY`, el flujo «Desplegar servidor» despliega desde GitHub.

## Pruebas

```bash
pip install -r requirements-dev.txt
python -m pytest -q tests
```

Usan DynamoDB simulado (moto) y verifican además que los tiempos de vida coincidan con `lib/models/report.dart`.

## Quitar todo

```bash
aws cloudformation delete-stack --stack-name ruta-libre-reportes
```
