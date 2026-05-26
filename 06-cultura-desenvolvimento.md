---
titulo: "Cultura de Desenvolvimento SEGAPE"
aliases:
  - "cultura"
  - "principios"
tags:
  - sql
  - dbt
  - git
  - workflow
  - cultura
data_criacao: "2026-01-01"
data_modificacao: "2026-04-08"
---

# Guia 06 — Cultura de Desenvolvimento SEGAPE

Este guia reúne práticas e princípios que a equipe aplica no dia a dia.
Não são regras arbitrárias -- cada uma surgiu de problemas reais encontrados em produção. Para as regras específicas, veja [[04-padroes-codigo]]. Para os erros mais comuns em reviews, veja [[07-erros-comuns-review]].

---

## Princípios

### Explícito sobre implícito

Se algo pode falhar silenciosamente, faça falhar alto.

- CAST falha com erro claro quando o dado é inválido (detalhes em [[04-padroes-codigo]]).
- SAFE_CAST retorna NULL sem avisar -- mascara bugs que vão aparecer depois (veja [[05-armadilhas]]).
- Comparações de string com UPPER evitam que uma mudança de casing na carga quebre o pipeline.

### Dados corretos são mais importantes que código bonito

Antes de refatorar, pergunte: "Os números estão certos?"

O fluxo de validação é (detalhes em [[03-fluxo-trabalho]]):
1. Executar o modelo (`dbt run`)
2. Conferir no BigQuery se os números batem com o esperado
3. Só então rodar linting e formatação (`pre-commit`)

### Código defensivo contra cargas futuras

O dado de amanhã pode vir diferente do de hoje. Padrões que protegem:

- `UPPER(campo) = 'VALOR'` — protege contra mudança de casing
- `sigla_edital` como chave de diferenciação — protege contra soma de editais
- `COALESCE(campo, 0)` em somas — protege contra NULLs inesperados
- Verificar indicadores booleanos em cada ano novo — podem vir NULL

### Escopo atômico

Bug encontrado ao implementar uma feature **não** é corrigido inline.
Registra-se como issue separada e corrige-se em outra PR.

PR de código (SQL/schema) **não inclui** documentação, guias ou scripts.
PR de documentação **não inclui** mudanças em modelos de dados.

Isso evita:
- PRs gigantes com mudanças não relacionadas
- Revisões demoradas por mistura de escopos
- Rollback acidental de correções ao reverter a feature
- Revisor precisando avaliar contextos completamente diferentes na mesma PR

---

## Padrões de Revisão

A revisão de código no projeto segue critérios específicos. Estes são os pontos
que os revisores verificam com mais frequência:

### Qualidade SQL

| Verificação | O que o revisor procura |
|-------------|----------------------|
| Tipos de dados | CAST correto, sem SAFE_CAST, sem CASTs redundantes |
| Strings | Comparações com UPPER/LOWER, preferência por IDs numéricos |
| Agregações | TRUNC/ROUND em somas de FLOAT, COALESCE para NULLs |
| CTEs | Sem refs duplicados, lógica consolidada |
| Colunas | Somente campos utilizados no dashboard |

### Documentação

| Verificação | O que o revisor procura |
|-------------|----------------------|
| schema.yml | Formato `//` separadores, campos obrigatórios preenchidos |
| Descrições | Claras, concisas, com acentuação correta |
| Frequência | Informada ou "Não informado" |
| Nível de observação | Corresponde à chave primária real |

### Organização

| Verificação | O que o revisor procura |
|-------------|----------------------|
| Escopo | Somente mudanças relacionadas ao objetivo da PR |
| Arquivos | Sem alterações em arquivos não relacionados |
| Commits | Mensagens descritivas em PT-BR |
| Branch | Apontando para `develop` |

---

## O que acontece quando esses padrões são ignorados

Casos reais que motivaram cada regra:

### SAFE_CAST mascarou dados inválidos
Testes passavam em dev porque SAFE_CAST retornava NULL para dados corrompidos.
Em produção, os dashboards mostravam valores menores que o real — os NULLs eram
descartados silenciosamente nas agregações.

### Soma sem diferenciação de edital
Ao chegar a segunda remessa de dados do programa Pé-de-Meia Licenciaturas,
os elegíveis duplicaram no painel (16.999 = soma de 2 editais). O campo `sigla_edital`
não estava na consulta porque antes só existia 1 edital.

### `+` no seletor destruiu policy tags
Um `dbt run` com `+painel_pdm_estudante_acumulado` re-materializou a tabela
`matricula_unica_pdm`, destruindo as policy tags IAM nas colunas `raca` e `genero`.
O modelo de incentivo passou a falhar com `Access Denied`. A restauração
dependeu da equipe de engenharia.

### Tabela do Censo com colunas renomeadas
O Censo Escolar 2025 mudou nomes de variáveis em relação ao 2024. Modelos que
referenciavam colunas pelo nome antigo quebraram silenciosamente — `dbt compile`
não detectou o problema, só o `dbt run` no BigQuery.

### PR para `main` rejeitada pelo CI
Uma PR foi aberta diretamente para `main` sem passar por `develop`.
O CI rejeitou automaticamente. A solução foi fechar a PR e reabrir apontando para `develop`.

---

## Resumo Operacional

```
1. Abrir o projeto e sincronizar
2. Criar branch a partir de develop
3. Implementar mudança com escopo definido
4. dbt run nos modelos afetados
5. Conferir números no BigQuery
6. pre-commit run --all-files
7. Commit com mensagem PT-BR descritiva
8. Push e abrir PR para develop
9. Aguardar revisão e aplicar ajustes
```

A equipe valoriza:
- Código que funciona corretamente antes de código que parece bonito
- Mensagens de commit que explicam o porquê, não apenas o quê
- PRs pequenas e focadas em vez de mudanças grandes e misturadas
- Documentação schema.yml completa e com acentuação correta

---

## Navegação

| Documento | Descrição |
|-----------|-----------|
| [03 - Fluxo de Trabalho](03-fluxo-trabalho.md) | Git workflow e PRs |
| [04 - Padrões de Código](04-padroes-codigo.md) | Standards de SQL, schema.yml, commits |
| [05 - Armadilhas](05-armadilhas.md) | Erros conhecidos e como evitá-los |
| [07 - Erros Comuns em Review](07-erros-comuns-review.md) | Exemplos antes/depois |

[Voltar ao índice](onboarding.md)
