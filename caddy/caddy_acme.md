# Plano: `caddy-acme-install.sh` para Caddy + acme.sh + Cloudflare

## Resumo
Criar um script raiz, idempotente e orientado por menu interativo + subcomandos para Debian/Ubuntu, focado em:
- instalar o Caddy pelo repositório oficial `apt`
- instalar e configurar `acme.sh` para emissão DNS-01 via Cloudflare
- usar certificados manuais em disco no Caddy
- manter a configuração modular em `/etc/caddy/Caddyfile` + `/etc/caddy/sites.d/*.caddy`
- priorizar certificados por host/FQDN, não wildcard, nesta v1

O script novo ficará na raiz como `caddy-acme-install.sh`, com documentação em `docs/scripts/caddy-acme-install.md` e entrada no `README.md`. O padrão de execução seguirá o restante do repositório: um arquivo único chamável por `bash -c "$(curl -fsSL ...)"`.

## Interface e mudanças principais
Interface pública do script:
- sem argumentos
  - abre menu interativo
  - oferece opções como `init`, `issue-cert`, `add-site`, `validate`, `upgrade-acme` e ajuda resumida
  - faz prompts para os parâmetros obrigatórios quando a opção escolhida precisar
- com argumentos
  - executa diretamente o subcomando informado, sem abrir menu
  - compatível com chamadas como `bash -c "$(curl -fsSL ...)" -- <subcomando> ...`
- `init`
  - wizard inicial quando chamado diretamente ou via menu
  - instala dependências, repo oficial do Caddy, `caddy`, `acme.sh`
  - cria `/etc/caddy-acme.conf` com permissões `0600`
  - cria `/etc/caddy/Caddyfile`, `/etc/caddy/sites.d/`, `/etc/caddy/certs/`
  - habilita/inicia `caddy`
- `issue-cert --domain <fqdn>`
  - carrega `/etc/caddy-acme.conf`
  - exporta `CF_Token` e exatamente um entre `CF_Account_ID` ou `CF_Zone_ID`
  - emite o certificado do FQDN via `acme.sh --issue --dns dns_cf -d <fqdn>`
  - instala em `/etc/caddy/certs/<fqdn>/fullchain.pem` e `privkey.pem`
  - ajusta permissões para leitura pelo serviço do Caddy
  - executa reload do Caddy ao final
- `add-site --domain <fqdn> --upstream <url> [--issue-if-missing] [--skip-upstream-tls-verify]`
  - cria ou atualiza um arquivo gerenciado em `/etc/caddy/sites.d/<fqdn>.caddy`
  - no menu interativo, emite o certificado automaticamente se ele ainda nao existir
  - no CLI, so emite automaticamente quando `--issue-if-missing` for usado
  - gera um bloco `reverse_proxy` genérico, sem presets específicos para PVE/PBS/UniFi/Kuma
  - referencia o certificado manual daquele FQDN
- `validate`
  - executa `caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile`
- `upgrade-acme`
  - executa o atualizador proprio do `acme.sh`
  - cobre o caso em que `apt upgrade` atualiza o Caddy, mas nao atualiza o `acme.sh`
- `--dry-run`
  - disponível nos subcomandos mutáveis

Arquivo de configuração persistente:
- `/etc/caddy-acme.conf`
- chaves previstas:
  - `ACME_EMAIL`
  - `CF_Token`
  - `CF_Account_ID` ou `CF_Zone_ID`
  - `CADDY_CERTS_DIR=/etc/caddy/certs`

Layout de configuração do Caddy:
- `/etc/caddy/Caddyfile`
  - opções globais mínimas
  - `import sites.d/*.caddy`
- `/etc/caddy/sites.d/<fqdn>.caddy`
  - um host por arquivo
  - `tls /etc/caddy/certs/<fqdn>/fullchain.pem /etc/caddy/certs/<fqdn>/privkey.pem`
  - `reverse_proxy` com suporte opcional a `tls_insecure_skip_verify` para upstream HTTPS interno

Regras de idempotência:
- arquivos gerados pelo script terão cabeçalho `Managed by caddy-acme-install.sh`
- reexecução atualiza apenas arquivos gerenciados pelo script
- se existir arquivo conflitante sem cabeçalho de gerenciamento, o script aborta e orienta o usuário, salvo `--force`
- `init` não apaga sites já existentes em `/etc/caddy/sites.d/`
- o menu interativo reaproveita os mesmos subcomandos internos; não haverá lógica separada para "modo menu" e "modo CLI"

## Testes e critérios de aceite
Cenários principais:
- host Debian/Ubuntu limpo: `init` conclui, instala Caddy/acme.sh e sobe o serviço sem erro
- reexecução de `init`: não duplica repositório `apt`, não duplica blocos no `Caddyfile`, não perde sites existentes
- `issue-cert --domain app.example.com`: grava certificados em caminho fixo, com reload automático do Caddy
- `add-site --domain app.example.com --upstream http://10.0.0.30:3001 --issue-if-missing`: emite o certificado se faltar, gera fragmento válido e `validate` passa
- `add-site --domain pve.example.com --upstream https://10.0.0.10:8006 --issue-if-missing --skip-upstream-tls-verify`: emite o certificado se faltar e gera transporte HTTPS interno compatível com PVE/PBS
- `--dry-run`: mostra ações sem alterar arquivos gerenciados

Aceite funcional:
- Caddy permanece atualizável via `apt upgrade`
- `acme.sh` fica atualizável pelo subcomando `upgrade-acme`
- nenhum plugin Cloudflare no Caddy
- renovação do `acme.sh` recarrega o Caddy automaticamente
- sem argumentos, o script abre um menu interativo utilizável para bootstrap e manutenção simples
- com argumentos, o script permite operação não interativa e previsível
- o operador consegue adicionar um host novo com no máximo:
  1. `issue-cert`
  2. `add-site`
  3. `validate`

## Assumptions e defaults
- alvo: Debian/Ubuntu apenas
- fonte do Caddy: repositório oficial do Caddy via `apt`
- `acme.sh` ficará no local padrão do root e usará o agendador nativo dele; a v1 não cria timer systemd próprio
- a v1 implementa apenas certificados por host/FQDN; wildcard fica fora do escopo inicial
- o script será genérico para reverse proxy; não haverá presets opinionados para serviços específicos nesta primeira versão
- a UX padrão será híbrida:
  - sem args: menu interativo
  - com args: subcomandos/parâmetros
- permissões esperadas:
  - `/etc/caddy-acme.conf` `0600 root:root`
  - diretórios de certificados com grupo legível pelo serviço do Caddy
  - chaves privadas nunca world-readable

Referências oficiais usadas no desenho:
- Caddy `tls` com certificado/chave manuais: https://caddyserver.com/docs/caddyfile/directives/tls
- instalação do Caddy por `apt`: https://caddyserver.com/docs/install
- `acme.sh` com Cloudflare `dns_cf`: https://github.com/acmesh-official/acme.sh/wiki/dnsapi#dns_cf
