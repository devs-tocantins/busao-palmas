import 'dart:convert';
import 'dart:io';

import 'package:busao_palmas/core/tema.dart';
import 'package:busao_palmas/data/dados_locais.dart';
import 'package:busao_palmas/data/paradas_repo.dart';
import 'package:busao_palmas/domain/models.dart';
import 'package:busao_palmas/features/parada/parada_page.dart';
import 'package:busao_palmas/state/parada.dart';
import 'package:busao_palmas/state/planejador.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

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

/// Repositório que devolve o que o teste mandar, sem rede.
class _RepoFalso extends ParadasRepo {
  _RepoFalso(this.resposta) : super(_dados());
  final Future<List<SaidasLinha>> Function() resposta;

  @override
  Future<List<SaidasLinha>> saidas(ParadaRef parada) => resposta();
}

const _parada = ParadaRef(
  nome: 'Av. NS 10 × Av. LO 4',
  pos: LatLng(-10.1789, -48.334),
);

Chegada _em(int min, {bool vivo = false, int? atraso}) => Chegada(
  horario: DateTime.now().add(Duration(minutes: min, seconds: 30)),
  aoVivo: vivo,
  atrasoSeg: atraso,
);

Widget _app(Future<List<SaidasLinha>> Function() resposta, {Widget? home}) =>
    ProviderScope(
      overrides: [
        dadosLocaisProvider.overrideWithValue(_dados()),
        paradasRepoProvider.overrideWithValue(_RepoFalso(resposta)),
      ],
      child: MaterialApp(
        theme: Tema.claro(),
        home: home ?? const ParadaPage(parada: _parada),
      ),
    );

Future<void> _celular(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('mostra o nome da parada e as linhas com o tempo que falta', (
    t,
  ) async {
    await _celular(t);
    await t.pumpWidget(
      _app(
        () async => [
          SaidasLinha(
            linha: '090',
            destino: 'Estação Apinajé / UFT',
            chegadas: [_em(7, vivo: true), _em(27), _em(47)],
          ),
          SaidasLinha(
            linha: '620',
            destino: 'Sol Nascente - Corujão',
            chegadas: [_em(125)],
          ),
        ],
      ),
    );
    await t.pump(const Duration(milliseconds: 300));

    expect(find.text('Av. NS 10 × Av. LO 4'), findsOneWidget);
    expect(find.text('090'), findsOneWidget);
    expect(find.text('620'), findsOneWidget);
    expect(find.text('em 7 min'), findsOneWidget);
    expect(find.text('Ao vivo'), findsOneWidget);
    expect(find.text('Programado'), findsOneWidget);
    expect(find.textContaining('Depois:'), findsOneWidget);
    expect(find.text('Sol Nascente - Corujão'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('ônibus a mais de 1 h mostra a hora, e muito atrasado avisa', (
    t,
  ) async {
    await _celular(t);
    await t.pumpWidget(
      _app(
        () async => [
          SaidasLinha(
            linha: '090',
            destino: 'UFT',
            chegadas: [_em(5, vivo: true, atraso: 300)],
          ),
          SaidasLinha(linha: '620', destino: 'Corujão', chegadas: [_em(125)]),
        ],
      ),
    );
    await t.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Atrasado 5 min'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d{2}:\d{2}$').hasMatch(w.data ?? ''),
      ),
      findsOneWidget,
      reason: 'o 620 está a 2 h: aparece a hora',
    );
  });

  testWidgets('sem ônibus: explica e não mostra lista vazia', (t) async {
    await _celular(t);
    await t.pumpWidget(_app(() async => const []));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Nenhum ônibus nas próximas horas'), findsOneWidget);
  });

  testWidgets('falha ao ler: mensagem clara e nada quebra', (t) async {
    await _celular(t);
    await t.pumpWidget(_app(() async => throw Exception('sem rede')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Não conseguimos atualizar agora'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('"Como chegar aqui" define a parada como destino e vai ao mapa', (
    t,
  ) async {
    await _celular(t);
    final router = GoRouter(
      initialLocation: '/parada',
      routes: [
        GoRoute(
          path: '/mapa',
          builder: (_, _) => const Scaffold(body: Text('MAPA')),
        ),
        GoRoute(
          path: '/parada',
          builder: (_, _) => const ParadaPage(parada: _parada),
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          dadosLocaisProvider.overrideWithValue(_dados()),
          paradasRepoProvider.overrideWithValue(
            _RepoFalso(() async => const []),
          ),
        ],
        child: MaterialApp.router(theme: Tema.claro(), routerConfig: router),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));

    await t.tap(find.text('Como chegar aqui'));
    await t.pump(const Duration(milliseconds: 300));

    expect(find.text('MAPA'), findsOneWidget);
    final c = ProviderScope.containerOf(t.element(find.text('MAPA')));
    expect(c.read(planejadorProvider).destino?.nome, 'Av. NS 10 × Av. LO 4');
    expect(c.read(planejadorProvider).destino?.ehParada, isTrue);
    await t.pump(const Duration(seconds: 1));
  });

  test('ParadaRef: mesmo lugar é igual mesmo com diferença minúscula nas coordenadas', () {
    const a = ParadaRef(nome: 'X', pos: LatLng(-10.178900001, -48.334));
    const b = ParadaRef(nome: 'X', pos: LatLng(-10.178900002, -48.334));
    const c = ParadaRef(nome: 'X', pos: LatLng(-10.1790, -48.334));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
  });
}
