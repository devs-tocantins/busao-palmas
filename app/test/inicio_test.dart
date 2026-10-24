import 'dart:convert';
import 'dart:io';

import 'package:busao_palmas/core/tema.dart';
import 'package:busao_palmas/data/dados_locais.dart';
import 'package:busao_palmas/data/paradas_repo.dart';
import 'package:busao_palmas/domain/models.dart';
import 'package:busao_palmas/features/inicio/inicio_page.dart';
import 'package:busao_palmas/state/parada.dart';
import 'package:busao_palmas/state/planejador.dart';
import 'package:busao_palmas/state/salvos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

DadosLocais _dados() {
  final p =
      jsonDecode(File('assets/data/paradas.json').readAsStringSync()) as List;
  final l =
      jsonDecode(File('assets/data/linhas.json').readAsStringSync()) as List;
  Color cor(String h) => Color(int.parse('FF${h.substring(1)}', radix: 16));
  return DadosLocais(
    [
      for (final x in p)
        ParadaLocal(
          x['id'] as int,
          x['nome'] as String,
          LatLng((x['lat'] as num).toDouble(), (x['lng'] as num).toDouble()),
        ),
    ],
    {
      for (final x in l)
        x['numero'] as String: LinhaLocal(
          x['numero'] as String,
          x['nome'] as String,
          cor(x['cor'] as String),
          cor(x['corTexto'] as String),
        ),
    },
  );
}

class _PlanejadorFalso extends PlanejadorNotifier {
  _PlanejadorFalso(this.inicial);
  final PlanejadorState inicial;

  @override
  PlanejadorState build() => inicial;

  @override
  Future<void> usarMinhaLocalizacao() async {}
}

class _RepoFalso extends ParadasRepo {
  _RepoFalso() : super(_dados());

  @override
  Future<List<SaidasLinha>> saidas(ParadaRef parada) async => [
    SaidasLinha(
      linha: '090',
      destino: 'Estação Apinajé / UFT',
      chegadas: [
        Chegada(
          horario: DateTime.now().add(const Duration(minutes: 7, seconds: 30)),
        ),
      ],
    ),
  ];
}

Future<GoRouter> _abrir(WidgetTester t, PlanejadorState estado) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const InicioPage()),
      GoRoute(
        path: '/mapa',
        builder: (_, _) => const Scaffold(body: Text('MAPA')),
      ),
      GoRoute(
        path: '/busca/:campo',
        builder: (_, s) =>
            Scaffold(body: Text('BUSCA ${s.pathParameters['campo']}')),
      ),
      GoRoute(
        path: '/parada',
        builder: (_, _) => const Scaffold(body: Text('PARADA')),
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        dadosLocaisProvider.overrideWithValue(_dados()),
        paradasRepoProvider.overrideWithValue(_RepoFalso()),
        planejadorProvider.overrideWith(() => _PlanejadorFalso(estado)),
      ],
      child: MaterialApp.router(theme: Tema.claro(), routerConfig: router),
    ),
  );
  await t.pump(const Duration(milliseconds: 300));
  return router;
}

// Perto da Estação Apinajé.
const _aqui = LatLng(-10.17792034, -48.3340683);

void main() {
  test('paradasPerto: ordenadas da mais perto, dentro do raio', () {
    final r = _dados().paradasPerto(_aqui, max: 5);
    expect(r, isNotEmpty);
    expect(r.length, lessThanOrEqualTo(5));
    expect(r.first.metros, lessThan(30));
    for (var i = 1; i < r.length; i++) {
      expect(r[i].metros, greaterThanOrEqualTo(r[i - 1].metros));
    }
    expect(r.every((p) => p.metros <= 600), isTrue);
    expect(_dados().paradasPerto(const LatLng(-11.5, -49.5)), isEmpty);
  });

  testWidgets('sem localização: pergunta, e não inventa paradas', (t) async {
    await _abrir(t, const PlanejadorState());
    expect(find.text('Para onde você vai?'), findsOneWidget);
    expect(find.text('Buscar destino'), findsOneWidget);
    expect(find.text('Usar minha localização'), findsOneWidget);
    expect(find.text('em 7 min'), findsNothing);
  });

  testWidgets('com localização: paradas perto com a próxima saída', (t) async {
    await _abrir(t, const PlanejadorState(minhaPos: _aqui));
    expect(find.text('Perto de você'), findsOneWidget);
    expect(find.text('090'), findsWidgets);
    expect(find.text('em 7 min'), findsWidgets);
    expect(find.text('Usar minha localização'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('tocar em Buscar destino abre a busca', (t) async {
    await _abrir(t, const PlanejadorState());
    await t.tap(find.text('Buscar destino'));
    await t.pumpAndSettle();
    expect(find.text('BUSCA destino'), findsOneWidget);
  });

  testWidgets('escolher um destino leva ao mapa', (t) async {
    await _abrir(t, const PlanejadorState());
    final c = ProviderScope.containerOf(t.element(find.text('Buscar destino')));
    c
        .read(planejadorProvider.notifier)
        .definirDestino(const Lugar(nome: 'UFT', pos: LatLng(-10.17, -48.36)));
    await t.pumpAndSettle();
    expect(find.text('MAPA'), findsOneWidget);
  });

  testWidgets('Casa e recentes aparecem no Início', (t) async {
    await _abrir(t, const PlanejadorState());
    final c = ProviderScope.containerOf(t.element(find.text('Buscar destino')));
    await c
        .read(salvosProvider.notifier)
        .definirCasa(const Lugar(nome: 'Minha rua', pos: LatLng(-10.2, -48.3)));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Minha rua'), findsOneWidget);
    expect(find.text('Casa'), findsOneWidget);
  });
}
