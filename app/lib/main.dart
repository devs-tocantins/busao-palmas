import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/dados_locais.dart';
import 'state/planejador.dart';

Future<void> main() async {
  // Endereços limpos na web (/parada?lat=…) em vez de /#/parada. Não faz nada no Android.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  final dados = await DadosLocais.carregar();
  runApp(
    ProviderScope(
      overrides: [dadosLocaisProvider.overrideWithValue(dados)],
      child: const BusaoPalmasApp(),
    ),
  );
}
