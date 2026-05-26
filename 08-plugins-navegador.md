---
titulo: "Plugins de Navegador Recomendados"
aliases:
  - "plugins"
  - "extensões"
  - "navegador"
tags:
  - ferramentas
  - setup
  - navegador
data_criacao: "2026-04-08"
data_modificacao: "2026-04-08"
---

# Plugins de Navegador Recomendados

Extensões que complementam o fluxo de trabalho da equipe. Instale como parte do [[01-setup-ambiente|setup inicial]]. #ferramentas

Todos os plugins listados são gratuitos e disponíveis para Chrome e navegadores baseados em Chromium (Edge, Brave, etc.).

---

## FireShot

### O que faz

Captura screenshots de páginas inteiras, incluindo áreas que exigem scroll. Diferente do screenshot nativo do navegador, o FireShot captura a página completa em uma única imagem.

### Por que a equipe usa

Dashboards no Looker Studio frequentemente ocupam mais que uma tela. Para documentar o estado de um painel (evidência de bug, validação visual, registro de antes/depois), precisamos de capturas completas.

Também útil para:
- Registrar o estado de um dashboard antes de uma alteração
- Documentar bugs visuais para issues no GitHub
- Gerar evidências de validação para a equipe de negócio

### Como instalar

1. Abrir a Chrome Web Store
2. Buscar por "FireShot"
3. Selecionar "Take Webpage Screenshots Entirely - FireShot"
4. Clicar em "Usar no Chrome"

### Dicas de uso

- **Captura completa**: Clique no ícone do FireShot e selecione "Capturar página inteira"
- **Formato**: Prefira PNG para dashboards (preserva qualidade) e PDF para relatórios longos
- **Nomeação**: Use o padrão `programa_tipo_data` (ex: `pdm_painel_incentivo_2026-04-08.png`)

---

## Google Docs Offline

### O que faz

Permite visualizar e editar documentos do Google Drive (Docs, Sheets, Slides) sem conexão com a internet.

### Por que a equipe usa

Reuniões presenciais, deslocamentos e problemas de rede são comuns. Com o plugin ativado, os documentos de referência ficam disponíveis mesmo offline.

### Como instalar

1. Abrir a Chrome Web Store
2. Buscar por "Google Docs Offline"
3. Clicar em "Usar no Chrome"
4. Acessar drive.google.com e ativar o modo offline nas configurações

### Dicas de uso

- Ative o modo offline apenas para documentos que você consulta com frequência -- cada arquivo ocupa espaço local
- Edições feitas offline são sincronizadas automaticamente ao reconectar
- Funciona apenas no Chrome (não no Firefox)

---

## PrintFriendly

### O que faz

Remove elementos desnecessários de páginas web (anúncios, menus, barras laterais) para gerar versões limpas para impressão ou PDF.

### Por que a equipe usa

Relatórios, documentações técnicas e páginas de referência frequentemente precisam ser compartilhados em formato limpo. O PrintFriendly gera PDFs compactos sem poluição visual.

### Como instalar

1. Abrir a Chrome Web Store
2. Buscar por "PrintFriendly"
3. Selecionar "Print Friendly & PDF"
4. Clicar em "Usar no Chrome"

### Dicas de uso

- Antes de gerar o PDF, remova manualmente imagens ou blocos irrelevantes clicando neles
- Use para gerar versões PDF de documentações internas quando precisar compartilhar por email
- Funciona bem com páginas de documentação do BigQuery e dbt

---

## Seletor de Cores (Color Picker / Eyedropper)

### O que faz

Permite capturar o código de cor (hex, RGB, HSL) de qualquer elemento visível na tela do navegador.

### Por que a equipe usa

Dashboards no Looker Studio precisam manter consistência visual. Ao replicar um padrão de cores de um painel existente ou seguir o manual de identidade visual, o seletor de cores evita "olhômetro" e garante os códigos exatos.

### Como instalar

1. Abrir a Chrome Web Store
2. Buscar por "ColorZilla" (a mais popular e estável)
3. Clicar em "Usar no Chrome"

Alternativa: "Eye Dropper" (mais leve, sem funcionalidades extras).

### Dicas de uso

- **Modo Eyedropper**: Clique no ícone e passe o mouse sobre qualquer elemento -- o código hex aparece em tempo real
- **Histórico de cores**: O ColorZilla mantém um histórico das últimas cores capturadas
- **Paleta do MEC**: Ao identificar as cores de um dashboard existente, registre-as em um documento compartilhado para referência da equipe
- O Chrome 110+ tem um eyedropper nativo no DevTools (Elements > Styles > clique em qualquer amostra de cor), mas o plugin é mais prático para uso rápido

---

## Navegação

| Documento | Descrição |
|-----------|-----------|
| [01 - Setup do Ambiente](01-setup-ambiente.md) | Configuração completa do ambiente local |

[Voltar ao índice](onboarding.md)
