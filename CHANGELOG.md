# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## [Unreleased]

### Changed

- Repositorio isolado do bash-stuffs; codigo em `~/lab/ai-alias`
- Destino padrao de aliases: `~/.config/ai-alias/aliases.sh` (override via `AI_ALIAS_TARGET`)

## [1.2.1] - 2026-05-20

### Changed

- README consolidado com guia do usuario (user-first)
- Secao de contribuicao e open source com link para guia do desenvolvedor
- `guia-usuario.md` reduzido a redirect para o README

## [1.2.0] - 2026-05-20

### Added

- Documentacao completa (guia usuario, guia desenvolvedor, referencia CLI)
- Script `scripts/test_api.sh` para validar conexao com API DeepSeek
- Menu interativo pos-geracao (aplicar / retry / sair)
- Preview com paineis (`consulta`, `gerado`, `acao`)
- Fallback de parse JSON via `python3` em `__ai_extract_content`
- Mensagens de despedida aleatorias ao sair

### Changed

- Refatoracao do modulo `ai-alias-cli.sh` (UI, parser multiline, apply flow)
- Endpoint API atualizado para `https://api.deepseek.com/chat/completions`
- Flag `--force` aplica sem confirmacao; loop interativo com retry

## [1.1.0] - 2025-10-10

### Added

- Modo debug (`AI_ALIAS_DEBUG=1`)
- Parser aceita separadores `::` e `|`
- Backups automaticos antes de aplicar alteracoes
- Historico de criacoes em `~/.config/ai-alias/history`

### Fixed

- Variavel `i` vazando para o terminal
- Chamada curl e extracao de resposta HTTP

## [1.0.0] - 2025-10-06

### Added

- CLI `ai-alias` com integracao DeepSeek
- Geracao de aliases, funcoes e modulos shell
