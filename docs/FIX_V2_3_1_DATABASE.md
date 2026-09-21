# Correção v2.3.1

Erro corrigido:
`column users.role does not exist`

Causa:
o banco PostgreSQL já existia antes da inclusão dos campos de perfil e aprovação.

A v2.3.1 executa automaticamente:
- ADD COLUMN IF NOT EXISTS role
- ADD COLUMN IF NOT EXISTS approval_status
- ADD COLUMN IF NOT EXISTS approved_by_user_id
- criação dos índices correspondentes

## Subir
```powershell
docker compose down
docker compose up --build
```

Não use `docker compose down -v`.

Depois teste novamente:
`POST /api/v1/auth/register`
