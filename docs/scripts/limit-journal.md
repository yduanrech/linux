# `individuais/limit-journal.sh`

Ajusta limites de retenção e espaço do `journald`.

## Executar

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/individuais/limit-journal.sh)"
```

## Parâmetros aplicados

- `SystemMaxUse=300M`
- `SystemKeepFree=500M`
- `SystemMaxFileSize=50M`
- `MaxRetentionSec=1month`

## Validação

```bash
journalctl --disk-usage
```

