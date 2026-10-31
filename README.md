# Ruta Libre

Mapa de lugares y rutas accesibles para personas con movilidad reducida y con discapacidad visual. Muestra qué lugares tienen entrada sin escalón, calcula rutas que evitan escaleras y peligros, y deja que la comunidad reporte obstáculos (rampa bloqueada, coladera abierta, banqueta rota) que caducan solos si nadie los confirma.

> Prototipo del MVP. Piloto: 1 km alrededor de UPIICSA (Iztacalco, CDMX).

## Funciones

| Función | Qué hace | Implementación |
| --- | --- | --- |
| Mapa accesible | Lugares con color **e ícono** según su accesibilidad (✓ accesible, − limitado, ✕ no accesible, ? sin dato); cruces como cuadrados | `flutter_map` + teselas de OSM; lugares de Overpass guardados por zona |
| Ficha del lugar | Entrada, baño accesible, guía podotáctil, notas; "Escuchar", "Cómo llegar", "¿Es correcto?" | Etiquetas `wheelchair`, `toilets:wheelchair`, `tactile_paving`, `kerb` |
| Reportar peligro | 8 tipos, gravedad, foto y nota opcionales; ubicación por GPS | `ReportRepository` (local en el prototipo) |
| Confirmar o descartar | "Sigue ahí" reinicia la caducidad; dos "Ya no está" lo cierran | `models/report.dart` |
| Ruta accesible | Perfil `wheelchair` (pendiente ≤ 6 %, sin escalones) o `foot-walking`; evita los peligros reportados | openrouteservice con `avoid_polygons` |
| Cerca de ti | Lista hablada de lugares y peligros con distancia y dirección ("a 40 metros, a tu derecha") | GPS + texto a voz |
| Aviso de peligro | Voz y vibración a 30 m de un peligro vigente | `core/hazard_alerts.dart` |
| Voz | "Qué hay cerca", "reportar", "dónde estoy", "quitar ruta" | `speech_to_text` |

El perfil (silla de ruedas, bastón o andadera, baja visión, ceguera) cambia el cálculo de rutas, el filtro del mapa y la guía por voz.

**Sobre la dirección:** no se usa brújula. Mientras la persona camina, el rumbo sale del GPS y las indicaciones son relativas ("a tu derecha"); si está quieta, se usan puntos cardinales ("al norte").

## Estructura

```
lib/
  config.dart               zona piloto, User-Agent, clave de rutas
  app_state.dart            estado + AppScope; coordina servicios y avisos
  core/                     lógica pura con pruebas: geo, parser de OSM,
                            petición/respuesta de rutas, descripciones, voz
  models/                   Place, Report (ciclo de vida), RouteResult, AppSettings
  services/                 lugares (Overpass + caché), reportes, rutas,
                            ubicación, voz
  features/                 una carpeta por pantalla
  widgets/                  marcadores del mapa y leyenda
test/                       pruebas de core/ y modelos + widgets
tool/patch_platforms.dart   permisos de Android e iOS
```

## Documentación

- [Manual técnico](docs/Manual_Tecnico_Ruta_Libre.pdf) ([Word](docs/Manual_Tecnico_Ruta_Libre.docx)): arquitectura, datos, algoritmos, pruebas, despliegue y código.
- [Manual de usuario](docs/Manual_Usuario_Ruta_Libre.pdf) ([Word](docs/Manual_Usuario_Ruta_Libre.docx)): instalación y uso paso a paso, voz y TalkBack, preguntas frecuentes.

## Interfaz

Tema claro y oscuro (sigue al sistema o se elige en Ajustes), letra Atkinson Hyperlegible incluida en la app, mapa a pantalla completa con la hoja «Cerca de ti», búsqueda con micrófono y filtros rápidos. Todos los colores cumplen contraste WCAG AA (mínimo 4.92:1).

## Cómo correrlo

Requisitos: Flutter 3.32 o superior y un teléfono con GPS.

```bash
# 1. Generar carpetas nativas (no toca lib/ ni test/)
flutter create --org com.drak028 --project-name ruta_libre --platforms android,ios .

# 2. Permisos y configuración nativa
dart run tool/patch_platforms.dart

# 3. Dependencias y pruebas
flutter pub get
flutter test

# 4. Ejecutar con la clave de openrouteservice (gratis en openrouteservice.org)
flutter run --dart-define=ORS_API_KEY=tu_clave
```

También se puede escribir la clave en **Ajustes → Rutas** (se guarda solo en ese dispositivo). Sin clave, todo funciona menos "Cómo llegar".

En Windows, los scripts de `setup/` automatizan todo: `instalar_entorno.bat` (entorno), `revisar.bat` (análisis y pruebas) y `generar_apk.bat` (APK de pruebas en `RutaLibre.apk`).

Antes de probar en campo, revisa `AppConfig.pilotCenter` en `lib/config.dart`: es el centro **aproximado** de UPIICSA; ajústalo con openstreetmap.org.

## Servicios externos y sus reglas

- **Teselas de OSM:** se envía un User-Agent propio (`userAgentPackageName`), se muestra la atribución y no hay descarga para uso sin conexión, como pide la [política de teselas](https://operations.osmfoundation.org/policies/tiles/). Si la app crece, hay que cambiar a un proveedor de teselas.
- **Overpass:** la instancia pública no debe ser el backend de una app, así que cada zona se descarga una vez y se guarda 7 días. Si el servidor responde 429 o 504, se usan los datos guardados.
- **openrouteservice:** plan estándar de 2,000 rutas al día y 40 por minuto. Los peligros a menos de 25 m del origen o destino no se envían como zona a evitar, porque la ruta fallaría.

## Siguiente paso: backend de reportes

`ReportRepository` es una interfaz. Para compartir reportes entre usuarios hay que crear una implementación HTTP (API Gateway + Lambda + DynamoDB, fotos en S3) y pasarla en `main.dart` en lugar de `LocalReportRepository`. No hace falta cambiar ninguna pantalla.

## Privacidad

- La ubicación se procesa en el teléfono; al compartir un reporte solo se envía la ubicación del peligro, no el recorrido.
- Las fotos se guardan en la carpeta privada de la app. La pantalla de reporte pide evitar rostros y placas.
- Los votos "¿Es correcto?" se guardan localmente para enviarlos después a OSM como notas.
