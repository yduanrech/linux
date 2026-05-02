# `caddy-acme-install.sh`

Instala o Caddy oficial via `apt` e/ou configura certificados com `acme.sh` usando Cloudflare DNS-01.

O Caddy usa certificados prontos em disco com `tls cert key`; ele nao precisa de plugin Cloudflare nem build customizado.
Tambem existe um modo `init-acme` para usar apenas `acme.sh` com Apache2, sem instalar Caddy.

## Executar

Menu interativo:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)"
```

Modo direto com subcomandos:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- init
```

Modo apenas `acme.sh` para Apache2:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- init-acme
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- issue-cert --domain app.example.com
```

O `--` apos o `bash -c` e necessario para passar argumentos ao script baixado.

No modo interativo, o script mostra um resumo e pede confirmacao antes de gravar configuracao, emitir certificado ou criar/atualizar um site. Ao adicionar um site pelo menu, ele emite o certificado automaticamente se ainda estiver faltando. No modo CLI com subcomandos, ele executa direto para continuar scriptavel.

## Fluxo recomendado

### Caddy

Primeira execucao:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- init
```

Adicionar um novo host:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- add-site \
  --domain app.example.com \
  --upstream http://10.0.0.10:3000 \
  --issue-if-missing

bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- validate
```

No modo CLI, `add-site` espera que o certificado do dominio ja exista em `CERTS_DIR/<fqdn>/`. O padrao novo e `/etc/ssl/acme-certs/<fqdn>/`. Se quiser emitir automaticamente quando estiver faltando, use `--issue-if-missing`.

Adicionar um upstream HTTPS interno com certificado self-signed, comum em PVE/PBS:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- add-site \
  --domain pve.example.com \
  --upstream https://10.0.0.10:8006 \
  --issue-if-missing \
  --skip-upstream-tls-verify
```

### Apenas acme.sh / Apache2

Primeira execucao sem instalar Caddy:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- init-acme
```

Emitir certificado:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- issue-cert --domain app.example.com
```

Por padrao, o certificado fica no mesmo diretorio generico usado tambem pelo modo Caddy:

```text
/etc/ssl/acme-certs/app.example.com/fullchain.pem
/etc/ssl/acme-certs/app.example.com/privkey.pem
```

Exemplo minimo de VirtualHost Apache:

```apache
<VirtualHost *:443>
    ServerName app.example.com

    SSLEngine on
    SSLCertificateFile /etc/ssl/acme-certs/app.example.com/fullchain.pem
    SSLCertificateKeyFile /etc/ssl/acme-certs/app.example.com/privkey.pem
</VirtualHost>
```

Se necessario, habilite SSL no Apache:

```bash
a2enmod ssl
systemctl reload apache2
```

O reload gravado para renovacoes nesse modo e `systemctl reload apache2`. Para customizar:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- init-acme \
  --certs-dir /etc/ssl/acme-certs \
  --reload-cmd "systemctl reload apache2"
```

## Subcomandos

- `init`: instala dependencias, repo oficial do Caddy, `caddy`, `acme.sh`, cria `/etc/caddy-acme.conf`, `/etc/caddy/Caddyfile`, `/etc/caddy/sites.d/` e `CERTS_DIR`.
- `init-acme`: instala/configura apenas `acme.sh` para Apache2, sem instalar Caddy. O padrao e `CERTS_DIR=/etc/ssl/acme-certs` e `RENEW_RELOAD_CMD=systemctl reload apache2`.
- `issue-cert --domain FQDN`: emite e instala o certificado em `CERTS_DIR/<fqdn>/`.
- `add-site --domain FQDN --upstream URL`: cria ou atualiza `/etc/caddy/sites.d/<fqdn>.caddy`. O upstream deve ser `http://host:porta` ou `https://host:porta`, sem path.
- `add-site --issue-if-missing`: emite o certificado antes de gravar o site se ele ainda nao existir.
- `validate`: executa `caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile`.
- `upgrade-acme`: atualiza o `acme.sh` pelo atualizador proprio dele.

## Arquivos criados

- `/etc/caddy-acme.conf`: configuracao persistente, permissao `0600`, com `ACME_EMAIL`, `CF_Token`, `CF_Account_ID` ou `CF_Zone_ID`, `WEB_SERVER`, `CERTS_DIR` e `RENEW_RELOAD_CMD`.
- `/etc/caddy/Caddyfile`: arquivo base gerenciado, com `import sites.d/*.caddy`.
- `/etc/caddy/sites.d/<fqdn>.caddy`: um reverse proxy por host, com bloco de `log` comentado como template opcional.
- `/etc/ssl/acme-certs/<fqdn>/fullchain.pem`: certificado instalado pelo `acme.sh` no caminho padrao novo.
- `/etc/ssl/acme-certs/<fqdn>/privkey.pem`: chave privada instalada pelo `acme.sh` no caminho padrao novo.

## Atualizacao

Atualizar o Caddy:

```bash
apt update && apt upgrade
```

Atualizar o `acme.sh`:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- upgrade-acme
```

As renovacoes dos certificados ficam a cargo do agendador criado pelo proprio `acme.sh`. O comando `--install-cert` grava um reload command para ajustar permissoes e recarregar o servico configurado apos renovacoes: Caddy no modo `init`, Apache2 no modo `init-acme`.

Os arquivos gerados pelo script passam por `caddy fmt --overwrite` antes da validacao, para manter o formato padrao do Caddy.

## Observacoes

- Requer Debian/Ubuntu e execucao como root.
- Esta versao nao implementa wildcard; o fluxo principal e um certificado por FQDN.
- O script atualiza arquivos gerenciados por ele e evita sobrescrever arquivos existentes sem o marcador `Managed by caddy-acme-install.sh`, salvo com `--force`.
- Use `--dry-run` para ver as acoes sem alterar o sistema.
- `add-site` e `validate` sao operacoes especificas do Caddy. No modo Apache, use `issue-cert` e configure o VirtualHost manualmente ou pela aplicacao.
- Exemplos prontos de `Caddyfile` ficam em `caddy/examples/`, incluindo PVE, PBS, UniFi, Uptime Kuma e n8n.
- Os sites gerados incluem um bloco `log` inteiro comentado. Para ativar access log por host, basta descomentar esse bloco.
