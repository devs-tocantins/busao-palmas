import 'dart:convert';
import 'dart:io';

import 'package:busao_palmas/core/tema.dart';
import 'package:busao_palmas/data/dados_locais.dart';
import 'package:busao_palmas/data/linhas_repo.dart';
import 'package:busao_palmas/data/paradas_repo.dart';
import 'package:busao_palmas/domain/models.dart';
import 'package:busao_palmas/features/inicio/inicio_page.dart';
import 'package:busao_palmas/features/linha/linha_page.dart';
import 'package:busao_palmas/data/frota_repo.dart';
import 'package:busao_palmas/state/frota.dart';
import 'package:busao_palmas/state/mapa.dart';
import 'package:busao_palmas/state/parada.dart';
import 'package:busao_palmas/state/planejador.dart';
import 'package:busao_palmas/state/salvos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _RepoFalso extends ParadasRepo {
  _RepoFalso() : super(_dados());

  @override
  Future<List<SaidasLinha>> saidas(ParadaRef parada) async => const [];
}

class _PlanejadorFalso extends PlanejadorNotifier {
  @override
  PlanejadorState build() => const PlanejadorState();

  @override
  Future<void> usarMinhaLocalizacao() async {}
}

const _parada = ParadaRef(
  nome: 'Estação Apinajé',
  pos: LatLng(-10.17792034, -48.3340683),
);

Future<ProviderContainer> _abrir(WidgetTester t, Widget tela) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  final dados = _dados();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => tela),
      GoRoute(
        path: '/linha/:numero',
        builder: (_, s) =>
            Scaffold(body: Text('LINHA ${s.pathParameters['numero']}')),
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        dadosLocaisProvider.overrideWithValue(dados),
        paradasRepoProvider.overrideWithValue(_RepoFalso()),
        planejadorProvider.overrideWith(_PlanejadorFalso.new),
        dadosLinhasProvider.overrideWith(
          (ref) async => DadosLinhas.montar(
            linhas: _json('linhas') as List,
            horarios: _json('horarios') as Map,
            trajetos: _json('trajetos') as Map,
            dados: dados,
          ),
        ),
        estiloMapaProvider.overrideWith((ref, escuro) async => null),
        frotaProvider.overrideWith((ref) => Stream.value(const <Onibus>[])),
      ],
      child: MaterialApp.router(theme: Tema.claro(), routerConfig: router),
    ),
  );
  await t.pump(const Duration(milliseconds: 600));
  return ProviderScope.containerOf(t.element(find.byType(Scaffold).first));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('favoritos: marcar, desmarcar e guardar no aparelho', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(salvosProvider.future);
    final n = c.read(salvosProvider.notifier);
    await n.alternarLinha('620');
    await n.alternarLinha('090');
    await n.alternarParada(_parada);
    expect(c.read(salvosProvider).value!.linhasFavoritas, ['620', '090']);

    // Outro "abrir o app": lê do aparelho.
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final s = await c2.read(salvosProvider.future);
    expect(s.linhasFavoritas, ['620', '090']);
    expect(s.paradasFavoritas, [_parada]);

    await c2.read(salvosProvider.notifier).alternarLinha('620');
    await c2.read(salvosProvider.notifier).alternarParada(_parada);
    final depois = c2.read(salvosProvider).value!;
    expect(depois.linhasFavoritas, ['090']);
    expect(depois.paradasFavoritas, isEmpty);
  });

  test('dados salvos antes dos favoritos continuam abrindo', () {
    final s = Salvos.fromJson({
      'versao': 1,
      'recentes': [
        {'nome': 'UFT', 'lat': -10.17, 'lng': -48.36},
      ],
    });
    expect(s.recentes.single.nome, 'UFT');
    expect(s.linhasFavoritas, isEmpty);
    expect(s.paradasFavoritas, isEmpty);
  });

  testWidgets('estrela na linha marca e desmarca', (t) async {
    final c = await _abrir(t, const LinhaPage(numero: '620'));
    expect(find.byTooltip('Favoritar linha'), findsOneWidget);
    await t.tap(find.byTooltip('Favoritar linha'));
    await t.pump(const Duration(milliseconds: 200));
    expect(c.read(salvosProvider).value!.linhasFavoritas, ['620']);
    expect(find.byTooltip('Remover linha dos favoritos'), findsOneWidget);
    await t.tap(find.byTooltip('Remover linha dos favoritos'));
    await t.pump(const Duration(milliseconds: 200));
    expect(c.read(salvosProvider).value!.linhasFavoritas, isEmpty);
  });

  testWidgets('Início mostra os favoritos e abre a linha', (t) async {
    final c = await _abrir(t, const InicioPage());
    expect(find.text('Favoritos'), findsNothing);
    await c.read(salvosProvider.notifier).alternarLinha('620');
    await c.read(salvosProvider.notifier).alternarParada(_parada);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Estação Apinajé'), findsOneWidget);
    await t.tap(find.text('620'));
    await t.pumpAndSettle();
    expect(find.text('LINHA 620'), findsOneWidget);
  });
}
