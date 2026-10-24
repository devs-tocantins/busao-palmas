import 'dart:convert';
import 'dart:io';

import 'package:busao_palmas/core/tema.dart';
import 'package:busao_palmas/data/dados_locais.dart';
import 'package:busao_palmas/data/otp_client.dart';
import 'package:busao_palmas/domain/models.dart';
import 'package:busao_palmas/features/planejar/planejar_page.dart';
import 'package:busao_palmas/features/rota/detalhe_rota_page.dart';
import 'package:busao_palmas/data/frota_repo.dart';
import 'package:busao_palmas/state/frota.dart';
import 'package:busao_palmas/state/mapa.dart';
import 'package:busao_palmas/state/planejador.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:busao_palmas/features/planejar/busca_page.dart';
import 'package:busao_palmas/state/salvos.dart';

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

/// Estado já com uma rota escolhida, sem rede nem GPS.
class _PlanejadorFalso extends PlanejadorNotifier {
  _PlanejadorFalso(this.inicial);
  final PlanejadorState inicial;

  @override
  PlanejadorState build() => inicial;

  @override
  Future<void> usarMinhaLocalizacao() async {}
}

Future<(PlanejadorState, DadosLocais)> estadoParaTeste({
  bool comRota = true,
}) async {
  final dados = _dados();
  final json = jsonDecode(
    File('test/fixtures/plan.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final grupos = agruparOpcoes(interpretarPlano(json, dados));
  final estado = PlanejadorState(
    origem: const Lugar(
      nome: 'Alameda 19, Quadra 1006 Sul',
      pos: LatLng(-10.2491, -48.3243),
    ),
    destino: const Lugar(
      nome: 'Quadra 405 Norte',
      pos: LatLng(-10.145, -48.342),
    ),
    grupos: AsyncData(grupos),
    selecionado: comRota ? grupos.first : null,
  );
  return (estado, dados);
}

Widget appParaTeste(
  PlanejadorState estado,
  DadosLocais dados,
  Widget tela, {
  Brightness brilho = Brightness.light,
}) {
  return ProviderScope(
    overrides: [
      dadosLocaisProvider.overrideWithValue(dados),
      estiloMapaProvider.overrideWith((ref, escuro) async => null),
      frotaProvider.overrideWith((ref) => Stream.value(const <Onibus>[])),
      planejadorProvider.overrideWith(() => _PlanejadorFalso(estado)),
    ],
    child: MaterialApp(
      theme: brilho == Brightness.light ? Tema.claro() : Tema.escuro(),
      home: tela,
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testesAtalhos();
  testesSemRota();
  testesProximaSaida();
  testWidgets(
    'detalhe da rota mostra a linha do tempo completa (celular, claro)',
    (t) async {
      // Tela alta: o cartão "seu ônibus" empurra a linha do tempo para baixo do painel.
      t.view.physicalSize = const Size(1080, 3600);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      final (estado, dados) = await estadoParaTeste();

      await t.pumpWidget(appParaTeste(estado, dados, const DetalheRotaPage()));
      await t.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('Horário do seu ônibus'), findsOneWidget);
      expect(tester(t, 'Alameda 19, Quadra 1006 Sul'), isTrue);
      expect(find.textContaining('Caminhe'), findsWidgets);
      expect(find.textContaining('Embarque'), findsWidgets);
      expect(find.textContaining('Desça aqui'), findsWidgets);
      expect(find.textContaining('chega às'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'detalhe da rota no tema escuro e em tela estreita não estoura o layout',
    (t) async {
      t.view.physicalSize = const Size(720, 1280);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);
      final (estado, dados) = await estadoParaTeste();

      await t.pumpWidget(
        appParaTeste(
          estado,
          dados,
          const DetalheRotaPage(),
          brilho: Brightness.dark,
        ),
      );
      await t.pump(const Duration(milliseconds: 600));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('tela de planejamento lista as opções com a sequência da rota', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final (estado, dados) = await estadoParaTeste(comRota: false);

    await t.pumpWidget(appParaTeste(estado, dados, const PlanejarPage()));
    await t.pump(const Duration(milliseconds: 800));

    expect(find.text('Alameda 19, Quadra 1006 Sul'), findsOneWidget);
    expect(find.text('Quadra 405 Norte'), findsOneWidget);
    expect(find.text('Sair agora'), findsOneWidget);
    expect(find.text('Chega primeiro'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('sem destino pergunta para onde ir', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      appParaTeste(const PlanejadorState(), _dados(), const PlanejarPage()),
    );
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Para onde você quer ir?'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

bool tester(WidgetTester t, String texto) =>
    find.text(texto).evaluate().isNotEmpty;

void testesSemRota() {
  testWidgets('sem ônibus explica o motivo e oferece outros horários', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final dados = _dados();
    final estado = PlanejadorState(
      origem: const Lugar(
        nome: 'Minha localização',
        pos: LatLng(-10.28, -48.32),
      ),
      destino: const Lugar(
        nome: 'Quadra 405 Norte',
        pos: LatLng(-10.16, -48.34),
      ),
      grupos: AsyncError(const SemRota('x'), StackTrace.empty),
    );

    await t.pumpWidget(appParaTeste(estado, dados, const PlanejarPage()));
    await t.pump(const Duration(milliseconds: 600));

    expect(find.text('Sem ônibus para esse trajeto agora'), findsOneWidget);
    expect(find.text('Sair às 06:00'), findsOneWidget);
    expect(find.text('Sair às 17:00'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

void testesProximaSaida() {
  testWidgets(
    'sem ônibus agora mostra o próximo horário e o botão para vê-lo',
    (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      // 05:10 em Palmas = 08:10 UTC, no futuro.
      final proxima = DateTime.now().toUtc().add(
        const Duration(hours: 5, minutes: 37),
      );
      final estado = PlanejadorState(
        origem: const Lugar(
          nome: 'Minha localização',
          pos: LatLng(-10.28, -48.32),
        ),
        destino: const Lugar(
          nome: 'Quadra 405 Norte',
          pos: LatLng(-10.16, -48.34),
        ),
        grupos: AsyncError(const SemRota('x'), StackTrace.empty),
        proxima: proxima,
      );

      await t.pumpWidget(appParaTeste(estado, _dados(), const PlanejarPage()));
      await t.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('Próximo ônibus às'), findsOneWidget);
      expect(find.textContaining('Sai daqui a'), findsOneWidget);
      expect(find.textContaining('Ver rota das'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('procurando o próximo ônibus mostra o aviso de espera', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final estado = PlanejadorState(
      origem: const Lugar(
        nome: 'Minha localização',
        pos: LatLng(-10.28, -48.32),
      ),
      destino: const Lugar(
        nome: 'Quadra 405 Norte',
        pos: LatLng(-10.16, -48.34),
      ),
      grupos: AsyncError(const SemRota('x'), StackTrace.empty),
      procurandoProxima: true,
    );

    await t.pumpWidget(appParaTeste(estado, _dados(), const PlanejarPage()));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Procurando o próximo ônibus…'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

const _casa = Lugar(
  nome: 'Quadra 1006 Sul',
  detalhe: 'Alameda 19',
  pos: LatLng(-10.2485, -48.319),
);
const _shoppingSalvo = Lugar(
  nome: 'Palmas Shopping',
  pos: LatLng(-10.18934, -48.33552),
);

/// O armazenamento carrega de verdade (assíncrono); o teste espera isso antes de olhar a tela.
Future<void> _carregarSalvos(WidgetTester t) async {
  final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  await t.runAsync(() => c.read(salvosProvider.future));
  await t.pump(const Duration(milliseconds: 300));
}

void _comSalvos(Salvos s) => SharedPreferences.setMockInitialValues({
  'salvos_v1': jsonEncode(s.toJson()),
});

void testesAtalhos() {
  Future<void> celular(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
  }

  testWidgets('início sem atalhos convida a definir casa e trabalho', (
    t,
  ) async {
    await celular(t);
    await t.pumpWidget(
      appParaTeste(const PlanejadorState(), _dados(), const PlanejarPage()),
    );
    await t.pump(const Duration(milliseconds: 600));

    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Trabalho'), findsOneWidget);
    expect(find.text('Toque para definir'), findsNWidgets(2));
    expect(find.text('Recentes'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('início mostra casa salva e os recentes', (t) async {
    await celular(t);
    _comSalvos(const Salvos(casa: _casa, recentes: [_shoppingSalvo]));
    await t.pumpWidget(
      appParaTeste(const PlanejadorState(), _dados(), const PlanejarPage()),
    );
    await t.pump(const Duration(milliseconds: 600));
    await _carregarSalvos(t);

    expect(find.text('Quadra 1006 Sul'), findsOneWidget);
    expect(
      find.text('Toque para definir'),
      findsOneWidget,
      reason: 'só o trabalho continua vazio',
    );
    expect(find.text('Recentes'), findsOneWidget);
    expect(find.text('Palmas Shopping'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('tocar em Casa define o destino', (t) async {
    await celular(t);
    _comSalvos(const Salvos(casa: _casa));
    await t.pumpWidget(
      appParaTeste(const PlanejadorState(), _dados(), const PlanejarPage()),
    );
    await t.pump(const Duration(milliseconds: 600));
    await _carregarSalvos(t);

    await t.tap(find.text('Casa'));
    await t.pump(const Duration(milliseconds: 100));

    final c = ProviderScope.containerOf(t.element(find.byType(PlanejarPage)));
    expect(c.read(planejadorProvider).destino?.nome, 'Quadra 1006 Sul');
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('tocar num recente define o destino', (t) async {
    await celular(t);
    _comSalvos(const Salvos(recentes: [_shoppingSalvo]));
    await t.pumpWidget(
      appParaTeste(const PlanejadorState(), _dados(), const PlanejarPage()),
    );
    await t.pump(const Duration(milliseconds: 600));
    await _carregarSalvos(t);

    await t.tap(find.text('Palmas Shopping'));
    await t.pump(const Duration(milliseconds: 100));

    final c = ProviderScope.containerOf(t.element(find.byType(PlanejarPage)));
    expect(c.read(planejadorProvider).destino?.nome, 'Palmas Shopping');
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('remover um recente tira o item da lista e do aparelho', (
    t,
  ) async {
    await celular(t);
    _comSalvos(const Salvos(recentes: [_shoppingSalvo]));
    await t.pumpWidget(
      appParaTeste(const PlanejadorState(), _dados(), const PlanejarPage()),
    );
    await t.pump(const Duration(milliseconds: 600));
    await _carregarSalvos(t);

    await t.tap(find.byTooltip('Remover dos recentes'));
    await t.pump(const Duration(milliseconds: 200));

    expect(find.text('Palmas Shopping'), findsNothing);
    final c = ProviderScope.containerOf(t.element(find.byType(PlanejarPage)));
    expect(c.read(salvosProvider).value!.recentes, isEmpty);
  });

  testWidgets('destino definido oferece salvar como casa ou trabalho', (
    t,
  ) async {
    await celular(t);
    final estado = PlanejadorState(
      origem: const Lugar(
        nome: 'Minha localização',
        pos: LatLng(-10.28, -48.32),
      ),
      destino: _shoppingSalvo,
      grupos: AsyncError(const SemRota('x'), StackTrace.empty),
    );
    await t.pumpWidget(appParaTeste(estado, _dados(), const PlanejarPage()));
    await t.pump(const Duration(milliseconds: 600));
    await t.scrollUntilVisible(
      find.text('Salvar destino:'),
      200,
      scrollable: find.byType(Scrollable).last,
    );

    await t.tap(find.widgetWithText(ActionChip, 'Casa'));
    await t.pump(const Duration(milliseconds: 300));

    final c = ProviderScope.containerOf(t.element(find.byType(PlanejarPage)));
    expect(c.read(salvosProvider).value!.casa?.nome, 'Palmas Shopping');
  });

  testWidgets('busca mostra atalhos e recentes antes de digitar', (t) async {
    await celular(t);
    _comSalvos(const Salvos(trabalho: _casa, recentes: [_shoppingSalvo]));
    await t.pumpWidget(
      appParaTeste(
        const PlanejadorState(),
        _dados(),
        const BuscaPage(modo: ModoBusca.destino),
      ),
    );
    await t.pump(const Duration(milliseconds: 600));
    await _carregarSalvos(t);

    expect(find.text('Para onde você vai?'), findsOneWidget);
    expect(find.text('Trabalho'), findsOneWidget);
    expect(find.text('Recentes'), findsOneWidget);
    expect(find.text('Palmas Shopping'), findsOneWidget);
    expect(find.text('Escolher no mapa'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'definir casa: título próprio, sem opções de viagem nem atalhos',
    (t) async {
      await celular(t);
      await t.pumpWidget(
        appParaTeste(
          const PlanejadorState(),
          _dados(),
          const BuscaPage(modo: ModoBusca.casa),
        ),
      );
      await t.pump(const Duration(milliseconds: 600));

      expect(find.text('Onde fica a sua casa?'), findsOneWidget);
      expect(find.text('Escolher no mapa'), findsNothing);
      expect(find.text('Minha localização'), findsNothing);
      expect(find.text('Toque para definir'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  test('modo de busca vindo da URL', () {
    expect(ModoBusca.doTexto('casa'), ModoBusca.casa);
    expect(ModoBusca.doTexto('trabalho'), ModoBusca.trabalho);
    expect(ModoBusca.doTexto('origem'), ModoBusca.origem);
    expect(ModoBusca.doTexto('qualquer'), ModoBusca.destino);
    expect(ModoBusca.doTexto(null), ModoBusca.destino);
  });
}
