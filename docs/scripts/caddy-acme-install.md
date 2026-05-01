# `caddy-acme-install.sh`

Instala o Caddy oficial via `apt` e configura certificados com `acme.sh` usando Cloudflare DNS-01.

O Caddy usa certificados prontos em disco com `tls cert key`; ele nao precisa de plugin Cloudflare nem build customizado.

## Executar

Menu interativo:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)"
```

Modo direto com subcomandos:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- init
```

O `--` apos o `bash -c` e necessario para passar argumentos ao script baixado.

No modo interativo, o script mostra um resumo e pede confirmacao antes de gravar configuracao, emitir certificado ou criar/atualizar um site. No modo CLI com subcomandos, ele executa direto para continuar scriptavel.

## Fluxo recomendado

Primeira execucao:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- init
```

Adicionar um novo host:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- issue-cert --domain app.example.com

bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- add-site --domain app.example.com --upstream http://10.0.0.10:3000

bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- validate
```

Adicionar um upstream HTTPS interno com certificado self-signed, comum em PVE/PBS:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- add-site \
  --domain pve.example.com \
  --upstream https://10.0.0.10:8006 \
  --skip-upstream-tls-verify
```

## Subcomandos

- `init`: instala dependencias, repo oficial do Caddy, `caddy`, `acme.sh`, cria `/etc/caddy-acme.conf`, `/etc/caddy/Caddyfile`, `/etc/caddy/sites.d/` e `/etc/caddy/certs/`.
- `issue-cert --domain FQDN`: emite e instala o certificado em `/etc/caddy/certs/<fqdn>/`.
- `add-site --domain FQDN --upstream URL`: cria ou atualiza `/etc/caddy/sites.d/<fqdn>.caddy`. O upstream deve ser `http://host:porta` ou `https://host:porta`, sem path.
- `validate`: executa `caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile`.
- `upgrade-acme`: atualiza o `acme.sh` pelo atualizador proprio dele.

## Arquivos criados

- `/etc/caddy-acme.conf`: configuracao persistente, permissao `0600`, com `ACME_EMAIL`, `CF_Token` e `CF_Account_ID` ou `CF_Zone_ID`.
- `/etc/caddy/Caddyfile`: arquivo base gerenciado, com `import sites.d/*.caddy`.
- `/etc/caddy/sites.d/<fqdn>.caddy`: um reverse proxy por host.
- `/etc/caddy/certs/<fqdn>/fullchain.pem`: certificado instalado pelo `acme.sh`.
- `/etc/caddy/certs/<fqdn>/privkey.pem`: chave privada legivel pelo grupo `caddy`.

## Atualizacao

Atualizar o Caddy:

```bash
apt update && apt upgrade
```

Atualizar o `acme.sh`:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- upgrade-acme
```

As renovacoes dos certificados ficam a cargo do agendador criado pelo proprio `acme.sh`. O comando `--install-cert` grava um reload command para ajustar permissoes e recarregar o Caddy apos renovacoes.

## Observacoes

- Requer Debian/Ubuntu e execucao como root.
- A v1 nao implementa wildcard; o fluxo principal e um certificado por FQDN.
- O script atualiza arquivos gerenciados por ele e evita sobrescrever arquivos existentes sem o marcador `Managed by caddy-acme-install.sh`, salvo com `--force`.
- Use `--dry-run` para ver as acoes sem alterar o sistema.
- Exemplos prontos de `Caddyfile` ficam em `caddy/examples/`, incluindo PVE, PBS, UniFi, Uptime Kuma e n8n.
