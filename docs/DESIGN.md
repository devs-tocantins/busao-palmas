# Design: base visual

Versão provisória. Valores definidos antes do protótipo; mudam só com decisão registrada aqui.
Direção: sóbrio e legível, no estilo do Uber (fundo claro, preto e branco, letra grande, cantos arredondados). Sem copiar telas, ícones ou textos de outros apps.

## Cores

Contraste calculado pela fórmula WCAG 2.1. Texto precisa de pelo menos 4,5:1; ícone e texto grande, 3:1.

| Papel | Claro | Escuro |
|---|---|---|
| Fundo | `#FFFFFF` | `#000000` |
| Superfície (cartões, painel) | `#F6F6F6` | `#1A1A1A` |
| Borda | `#E2E2E2` | `#333333` |
| Texto principal | `#141414` (18,4:1) | `#FFFFFF` (21:1) |
| Texto secundário | `#5E5E5E` (6,5:1) | `#B5B5B5` (10,2:1) |
| Botão primário | fundo `#000000`, texto `#FFFFFF` (21:1) | fundo `#FFFFFF`, texto `#000000` |
| Destaque (amarelo de Palmas) | `#FFD100`, sempre com texto `#000000` (14,4:1) | igual |
| Secundária (azul) | `#0B5FA5` (6,6:1) | `#6AA9E8` (8,5:1) |
| Ao vivo | `#0E7A37` (5,4:1) | `#4CC27A` (9,3:1) |
| Atraso | `#9A4A00` (6,3:1) | a definir |
| Erro | `#C62828` (5,6:1) | a definir |

Regras:
- **Amarelo nunca é cor de texto sobre fundo claro** (1,5:1). Só como fundo de selo, realce ou ícone ativo, com texto preto.
- **Linhas de ônibus** usam `cor` e `corTexto` de `linhas.json` (hoje todas `#007CBA` com texto branco, 4,6:1).
- Verde "ao vivo" e cinza "programado" sempre acompanhados de texto ou ícone, nunca só a cor.
- O amarelo `#FFD100` vem da marca da operadora em `project-details`. As cores oficiais do município são azul, amarelo e branco
  (Lei Municipal 93/1991, brasão); a bandeira do estado também tem azul, branco e amarelo. Nenhuma das duas fontes que achamos traz código
  de cor, então o azul secundário é nosso, escolhido para ter contraste.

## Tipografia

Inter, empacotada no app (licença aberta, números legíveis). Tamanhos em px lógicos; o app deve respeitar a escala de fonte do sistema até 200%.

| Uso | Tamanho / linha | Peso |
|---|---|---|
| Duração da rota | 32 / 36 | 700 |
| Título de tela | 24 / 28 | 700 |
| Título de seção | 18 / 24 | 600 |
| Corpo | 16 / 24 | 400 |
| Número da linha no cartão | 18 / 22 | 700 |
| Legenda | 14 / 20 | 400 |

Nada abaixo de 14.

## Espaço e forma

- Base de 4: 4, 8, 12, 16, 24, 32. Margem lateral de tela: 16.
- Cantos: cartão 12, painel que sobe 20 no topo, botão e etiqueta de linha totalmente arredondados.
- Alvo de toque mínimo 48 × 48. Espaço mínimo de 8 entre alvos.
- Sombra só no painel que sobe e em cartões flutuantes sobre o mapa.

## Marca

Frente de ônibus preta com um pino de localização no para-brisa, sobre amarelo Palmas (`#FFD100`). Fonte do nome: Roboto Black.

- Arquivos em `app/assets/brand/`: `icone` (app), `icone-primeiro-plano` e `icone-monocromatico` (ícone adaptativo e temático do Android), `simbolo`/`simbolo-claro` (sem fundo), `logo`/`logo-escuro` (símbolo + nome).
- Tudo é gerado por `tools/marca.mjs` (SVG e PNG). Para mudar a marca, edite o script e rode `cd tools && node marca.mjs`; depois `cd app && dart run flutter_launcher_icons` refaz os ícones do Android e da web.
- O símbolo tem furos de verdade (janela, faróis, pino), então funciona sobre qualquer cor. Use preto sobre claro e amarelo sobre escuro; não recolorir de outro jeito.

## Estados que toda tela precisa ter

| Estado | Texto padrão |
|---|---|
| Carregando | esqueleto no formato do conteúdo; sem rodinha sozinha |
| Sem internet | "Sem internet. Mostrando os horários de [data]." (dados do snapshot) |
| Sem ônibus agora | "Nenhum ônibus nesta linha agora. Próximo às [hora]." |
| Sem rota | "Não achamos ônibus para esse trajeto neste horário." + sugerir outro horário |
| Erro da API | "Não conseguimos atualizar agora. Tente de novo." + botão |
| Horário ao vivo | "em 3 min", ícone e verde |
| Horário programado | "15:40", cinza, sem ícone de ao vivo |

## Acessibilidade

- Toda informação tem rótulo para leitor de tela (a sequência `andar 7 › 180 › 040` é lida como frase: "andar 7 minutos, ônibus 180, ônibus 040").
- Contraste e alvo conforme acima; testar em tela com brilho baixo e sob sol.
- Respeitar "reduzir animações" do sistema.
- Foco visível na versão web (navegação por teclado).
