# Como contribuir

## Corrigir o nome de uma parada

Os nomes vêm do OpenStreetMap e às vezes ficam estranhos ou vazios (cerca de 15% das paradas só têm o código).
Para corrigir, adicione o código da parada e o nome em `data/paradas_nomes.json`:

```json
{
  "37763930": "Av. NS 10 × Av. LO 4 · em frente ao Colégio X"
}
```

- O código aparece no app como "Parada 37763930" quando não há nome.
- Formato do nome: `Rua principal × rua que cruza`, ou `Rua · perto de <lugar conhecido>`.
- Correção aqui vale mais que a do OpenStreetMap. Se a rua estiver errada no mapa, corrija também em openstreetmap.org: ajuda todo mundo.

## Adicionar apelido de lugar

Em `data/apelidos.json`, sigla ou nome popular → nome como está no OpenStreetMap:

```json
{ "unitins": "Universidade Estadual do Tocantins" }
```

Para testar, rode `node tools/indice-busca.mjs` e confira no resultado se o nome existe.

## Código

- Antes de abrir um pull request, descreva em uma frase o problema que ele resolve.
- Mudou como a API é usada? Atualize [docs/API_MOBILIBUS.md](docs/API_MOBILIBUS.md).
- Documentação: só o que o leitor precisa para decidir ou agir. Veja `.claude/skills/documentar/SKILL.md`.
- Não adicione prints, APKs ou arquivos de outros apps ao repositório.
