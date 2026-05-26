# Sprint 5 - CLI Interativo e Polish

**Status:** NAO INICIADA
**Dependencia:** Sprint 4 (diagnostico)
**Objetivo:** Interface rica no terminal, modos de uso avancados, reutilizabilidade.

## Entregas

### 5.1 validador.py - CLI Principal
- [ ] Ponto de entrada unico com argparse
- [ ] Modos de uso:
  ```bash
  # Modo direto - escaneia um municipio
  python validador.py --municipio "Andradina - SP"

  # Modo direto com ano especifico
  python validador.py --municipio "Andradina - SP" --ano 2025

  # Modo batch - lista de municipios
  python validador.py --batch municipios.txt

  # Modo interativo - menu no terminal
  python validador.py

  # Modo dry-run - mostra queries sem executar
  python validador.py --municipio "Andradina - SP" --dry-run

  # Modo SQL - so gera as queries para copiar no console BQ
  python validador.py --municipio "Andradina - SP" --sql-only

  # Exportar relatorio
  python validador.py --municipio "Andradina - SP" --exportar csv
  ```

### 5.2 Menu Interativo (rich/textual)
- [ ] Selecao de municipio com autocomplete (lista de municipios do IBGE)
- [ ] Selecao de tabelas especificas ou "todas"
- [ ] Selecao de ano
- [ ] Visualizacao de resultados em tabela formatada
- [ ] Opcao de drill-down: selecionar tabela ZERO e ver upstream
- [ ] Opcao de copiar query para clipboard

### 5.3 Cache e Performance
- [ ] Cache local em SQLite ou JSON
- [ ] TTL configuravel (padrao: 24h)
- [ ] Flag --no-cache para forcar re-scan
- [ ] Exibir "cache hit" quando usar resultado anterior

### 5.4 Protecao de Custo
- [ ] Limite maximo de bytes por sessao (configuravel, padrao 500MB)
- [ ] Alerta quando atingir 80% do limite
- [ ] Abort automatico ao atingir 100%
- [ ] Log de custo acumulado visivel no terminal

### 5.5 Reutilizabilidade
- [ ] inventario.csv e o unico ponto de configuracao de tabelas
- [ ] Adicionar nova tabela = nova linha no CSV
- [ ] linhagem.json regeneravel automaticamente
- [ ] Funciona para qualquer municipio do Brasil
- [ ] Configuracao via .env ou config.py (sem hardcode)

## Criterios de Aceite

- `python validador.py` sem argumentos abre menu interativo
- `python validador.py --municipio X` executa scan completo automatico
- Resultados coloridos e alinhados no terminal
- Custo total monitorado e limitado
- Cache funcional evita re-scan desnecessario
- Adicionar nova tabela ao CSV nao exige mudanca de codigo
