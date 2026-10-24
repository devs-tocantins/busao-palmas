# Busão Palmas

App gratuito e sem login para ver os ônibus de Palmas-TO: escolher de onde para onde, ver o que andar a pé, quais ônibus pegar e onde trocar.
Feito pela comunidade Devs Tocantins. Projeto independente, com dados públicos; não é da SOU Palmas nem da Mobilibus.
Mapas e nomes de ruas e lugares: © colaboradores do OpenStreetMap (ODbL).

**Estado (2026-10-24):** em desenho. As ferramentas de dados funcionam; o app Flutter ainda não foi criado.

## Onde está cada coisa

| Pasta | Conteúdo |
|---|---|
| `docs/` | [Arquitetura](docs/ARQUITETURA.md), [rota de A para B](docs/UX_ROTA.md), [API de dados](docs/API_MOBILIBUS.md) |
| `tools/` | Scripts Node que geram os dados do app (paradas com nome legível, índice de busca) |
| `data/` | Arquivos que a comunidade edita: `apelidos.json`, `paradas_nomes.json`. `data/gerado/` é saída das ferramentas |
| `app/` | App Flutter (a criar) |
| `edge/` | Proxy para a versão web (a criar) |

## Gerar os dados

Precisa de Node 20 ou mais novo.

```bash
cd tools
node paradas.mjs   # data/gerado/paradas.json
node indice-busca.mjs   # data/gerado/busca.json
```

Na primeira execução baixa ruas e lugares do OpenStreetMap e guarda em `tools/.cache/`.

## Contribuir

Veja [CONTRIBUTING.md](CONTRIBUTING.md). A forma mais fácil de ajudar é corrigir nomes de paradas e adicionar apelidos de lugares.

## Licença

[MIT](LICENSE).
