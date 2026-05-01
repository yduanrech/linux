# Caddy Examples

Exemplos de blocos `Caddyfile` para uso com `caddy-acme-install.sh`.

## Regra pratica

Para backends HTTPS internos como Proxmox VE, Proxmox Backup Server e UniFi Controller, existem dois modos:

- `trusted-ca`: melhor pratica. O Caddy confia na CA interna do backend.
- `skip-verify`: mais simples para teste ou ambientes pequenos, mas menos seguro.

Quando o upstream e um IP, mas o certificado interno do backend foi emitido para um nome DNS, use `tls_server_name` para o nome que aparece no certificado.

## Arquivos

- `pve-trusted-ca.caddy`: Proxmox VE WebUI com CA confiada.
- `pve-skip-verify.caddy`: Proxmox VE WebUI com `tls_insecure_skip_verify`.
- `pbs-trusted-ca.caddy`: PBS WebUI com CA confiada.
- `pbs-skip-verify.caddy`: PBS WebUI com `tls_insecure_skip_verify`.
- `unifi-trusted-ca.caddy`: UniFi Network Controller com CA confiada.
- `unifi-skip-verify.caddy`: UniFi Network Controller com `tls_insecure_skip_verify`.
- `uptime-kuma-http.caddy`: exemplo simples de backend HTTP.
- `n8n-http.caddy`: exemplo simples de backend HTTP.

## Observacoes

- Para PVE, o reverse proxy e viavel para a WebUI. Consoles e noVNC dependem de WebSocket, e o `reverse_proxy` do Caddy lida com isso automaticamente.
- Para PBS, use reverse proxy so para a WebUI. O trafego real de backup e restore deve continuar indo direto para o PBS em `:8007`.
- Para PVE/PBS com certificado interno proprio, o modo `trusted-ca` costuma exigir copiar a CA do backend para o host do Caddy.
