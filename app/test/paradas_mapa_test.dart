import 'dart:convert';
import 'dart:io';

import 'package:busao_palmas/core/tema.dart';
import 'package:busao_palmas/data/dados_locais.dart';
import 'package:busao_palmas/data/otp_client.dart';
import 'package:busao_palmas/domain/models.dart';
import 'package:busao_palmas/state/planejador.dart';
import 'package:busao_palmas/widgets/camada_paradas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

dynamic _json(String n) =>
    jsonDecode(File('assets/data/$n.json').readAsStringSync());

DadosLocais _dados() {
  Color cor(String h) => Color(int.parse('FF${h.substring(1)}', radix: 16));
  return DadosLocais(
    [
      for (final x in _json('paradas') as List)
        ParadaLocal(
          x['id'] as int,
          x['nome'] as String,
          LatLng((x['lat'] as num).toDouble(), (x['lng'] as num).toDouble()),
        ),
    ],
    {
      for (final x in _json('linhas') as List)
        x['numero'] as String: LinhaLocal(
          x['numero'] as String,
          x['nome'] as String,
          cor(x['cor'] as String),
          cor(x['corTexto'] as String),
        ),
    },
  );
}

// Perto da Estação Apinajé, onde há várias paradas.
const _centro = LatLng(-10.17792034, -48.3340683);

Future<void> _mapa(WidgetTester t, double zoom) async {
  t.view.physicalSize = const Size(1080, 1600);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: FlutterMap(
            options: MapOptions(initialCenter: _centro, initialZoom: zoom),
            children: const [CamadaParadas()],
          ),
        ),
      ),
      GoRoute(
        path: '/parada',
        builder: (_, _) => const Scaffold(body: Text('PARADA')),
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [dadosLocaisProvider.overrideWithValue(_dados())],
      child: MaterialApp.router(theme: Tema.claro(), routerConfig: router),
    ),
  );
  await t.pump(const Duration(milliseconds: 300));
}

/// Guarda como o planejador foi chamado, sem rede.
class _OtpFalso extends OtpClient {
  _OtpFalso() : super(_dados());
  final chamadas = <({DateTime? saida, bool chegarAs})>[];

  @override
  Future<List<Opcao>> planejar({
    required LatLng de,
    required LatLng para,
    DateTime? saida,
    bool chegarAs = false,
  }) async {
    chamadas.add((saida: saida, chegarAs: chegarAs));
    throw const SemRota('sem rota');
  }
}

void main() {
  testWidgets('longe (zoom 12) não mostra paradas', (t) async {
    await _mapa(t, 12);
    expect(find.bySemanticsLabel(RegExp('^Parada ')), findsNothing);
  });

  testWidgets('perto (zoom 16) mostra paradas e tocar abre a parada', (
    t,
  ) async {
    await _mapa(t, 16);
    final paradas = find.bySemanticsLabel(RegExp('^Parada '));
    expect(paradas, findsWidgets);
    await t.tap(paradas.first);
    await t.pumpAndSettle();
    expect(find.text('PARADA'), findsOneWidget);
  });

  test('chegar às: o planejador pede arriveBy e sair às não', () async {
    final otp = _OtpFalso();
    final c = ProviderContainer(
      overrides: [
        dadosLocaisProvider.overrideWithValue(_dados()),
        otpClientProvider.overrideWithValue(otp),
        planejadorProvider.overrideWith(_PlanejadorQuieto.new),
      ],
    );
    addTearDown(c.dispose);
    final n = c.read(planejadorProvider.notifier);
    n.definirOrigem(const Lugar(nome: 'A', pos: LatLng(-10.2, -48.3)));
    n.definirDestino(const Lugar(nome: 'B', pos: LatLng(-10.18, -48.33)));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    n.definirChegada(8, 30);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(planejadorProvider).chegada, isTrue);
    expect(otp.chamadas.last.chegarAs, isTrue);
    final quando = otp.chamadas.last.saida!.toUtc().subtract(
      const Duration(hours: 3),
    );
    expect((quando.hour, quando.minute), (8, 30));

    n.definirSaida(7, 0);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(planejadorProvider).chegada, isFalse);
    expect(otp.chamadas.last.chegarAs, isFalse);

    n.definirChegada(9);
    n.definirSaida(null);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      c.read(planejadorProvider).chegada,
      isFalse,
      reason: 'sair agora desfaz',
    );
    expect(c.read(planejadorProvider).saida, isNull);
  });
}

/// Planejador sem GPS e sem a busca de "próximo ônibus" (que chamaria a rede).
class _PlanejadorQuieto extends PlanejadorNotifier {
  @override
  PlanejadorState build() => const PlanejadorState();
}
