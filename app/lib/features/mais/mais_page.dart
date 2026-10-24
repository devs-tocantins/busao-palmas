import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/tema.dart';

/// Sobre o app: quem faz, de onde vêm os dados e onde reclamar ou ajudar.
class MaisPage extends StatelessWidget {
  const MaisPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget item(IconData i, String titulo, String texto) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(i, color: cs.onSurfaceVariant),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(texto),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Tokens.margem,
            16,
            Tokens.margem,
            24,
          ),
          children: [
            Text(
              Config.nomeApp,
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Ônibus de ${Config.cidade}, grátis e sem cadastro.',
              style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            item(
              Icons.groups_rounded,
              'Feito pela comunidade',
              'Devs Tocantins. Não é um app oficial da prefeitura.',
            ),
            item(
              Icons.directions_bus_rounded,
              'Dados dos ônibus',
              'Os mesmos do app SOU Palmas (Mobilibus). Se algo estiver diferente, vale o SOU.',
            ),
            item(
              Icons.map_outlined,
              'Mapa',
              'OpenStreetMap, servido pelo OpenFreeMap.',
            ),
            item(
              Icons.code_rounded,
              'Código aberto',
              'github.com/devs-tocantins/busao-palmas (licença MIT). Sugestões e correções são bem-vindas.',
            ),
          ],
        ),
      ),
    );
  }
}
