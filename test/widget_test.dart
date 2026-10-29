// También evita que `flutter create .` genere la prueba del contador de ejemplo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ruta_libre/models/place.dart';
import 'package:ruta_libre/widgets/map_markers.dart';

void main() {
  testWidgets('el marcador expone su descripción al lector de pantalla',
      (tester) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    const place = Place(
      osmType: 'node',
      osmId: 1,
      name: 'Farmacia Ejemplo',
      category: 'Farmacia',
      location: LatLng(19.3958, -99.0912),
      kind: PlaceKind.poi,
      access: Accessibility.limited,
    );

    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 44,
          height: 44,
          child: PlaceMarker(
            place: place,
            semanticLabel: 'Farmacia Ejemplo. Acceso limitado.',
            onTap: () => taps++,
          ),
        ),
      ),
    ));

    expect(
      tester.getSemantics(find.byType(PlaceMarker)),
      containsSemantics(label: 'Farmacia Ejemplo. Acceso limitado.', isButton: true),
    );
    // Acceso limitado se distingue por ícono, no solo por color.
    expect(find.byIcon(Icons.remove), findsOneWidget);

    await tester.tap(find.byType(PlaceMarker));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('la leyenda explica cada estado', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AccessLegend()),
    ));
    for (final a in Accessibility.values) {
      expect(find.textContaining(a.label), findsOneWidget);
    }
    expect(find.textContaining('Peligro reportado'), findsOneWidget);
  });
}
