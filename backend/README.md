# Rico Investidor — Backend

## Banco de dados

### Desenvolvimento (SQLite — padrão)

Sem `DATABASE_URL`, o app usa `data/ricoapp.db` e cria as tabelas no startup.

### PostgreSQL (produção / dev local)

#### Opção A — Homebrew (Mac, sem Docker)

Se `docker` não existir no terminal, use o Postgres nativo:

```bash
# Corrija permissões do Homebrew se brew install falhar:
# sudo chown -R $(whoami) /opt/homebrew

brew install postgresql@16
brew services start postgresql@16
echo 'export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
createdb ricoapp
```

No `backend/.env` ou `~/Secrets/ricoapp1/.env`:

```env
DATABASE_URL=postgresql+psycopg://ivanlimadev@127.0.0.1:5432/ricoapp
```

(substitua `ivanlimadev` pelo seu usuário do Mac, se for diferente)

#### Opção B — Docker (se tiver Docker Desktop)

```bash
docker compose -f docker-compose.postgres.yml up -d
```

```env
DATABASE_URL=postgresql+psycopg://rico:rico@127.0.0.1:5432/ricoapp
```

#### Rodar a API

O projeto usa um virtualenv em `backend/.venv`. Ative antes de `pip`/`uvicorn`:

```bash
cd /Users/ivanlimadev/ricoapp1/backend
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Sem ativar o venv, use os binários diretos:

```bash
.venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

### Migrações manuais

```bash
cd backend
alembic upgrade head
alembic revision --autogenerate -m "descricao"
```

### Produção

Defina `APP_ENV=production` e use PostgreSQL. SQLite é rejeitado pelo guard de produção.
