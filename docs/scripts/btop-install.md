# `btop-install.sh`

Instala o `btop` em Ubuntu/Debian (arquiteturas `x86_64` e `aarch64`).

## Executar

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/btop-install.sh)"
```

## O que o script faz

- Instala dependências (`wget`, `make`, `bzip2`)
- Detecta arquitetura
- Baixa release do `btop`
- Extrai e roda `make install`
- Limpa arquivos temporários

## Validação

```bash
btop
```

