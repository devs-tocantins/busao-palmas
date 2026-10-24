import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/dados_locais.dart';
import 'state/planejador.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dados = await DadosLocais.carregar();
  runApp(
    ProviderScope(
      overrides: [dadosLocaisProvider.overrideWithValue(dados)],
      child: const BusaoPalmasApp(),
    ),
  );
}
