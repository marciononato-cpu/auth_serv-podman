# 🚀 LABONO Auth Service

Serviço de autenticação seguro e stateless com **JWT**, confirmação de email, rate limiting, OAuth (Google/Apple), painel administrativo e deploy via Docker.

---

## 📋 Stack

| Camada | Tecnologia |
|--------|-----------|
| **API** | Ruby on Rails 8.1.3 (API-only) |
| **Autenticação** | JWT (HS256, 24h expiry) + bcrypt |
| **Cache / Rate Limit** | Redis 7 |
| **Banco** | PostgreSQL 16 |
| **Proxy** | Caddy 2 (Alpine) |
| **Container** | Podman + podman-compose |
| **Testes** | RSpec + Minitest |
| **CI** | GitHub Actions (Brakeman, Bundler-audit, RuboCop) |
| **Deploy** | Kamal |

---

## 🏗️ Arquitetura

### Isolamento Podman

```
        Host:8084
           │
     ┌─────▼──────┐
     │   Caddy    │  (única porta exposta)
     │  (Alpine)  │
     └─────┬──────┘
           │ proxy reverso
     ┌─────▼──────┐
     │   Rails    │  (porta interna 3001)
     │    API     │
     └──┬─────┬───┘
        │     │
   ┌────▼──┐ ┌▼────┐
   │  PG   │ │Redis│
   │  16   │ │  7  │
   └───────┘ └─────┘
```

- **Caddy**: único ponto de entrada (porta `8084`)
- **Rails**, **PostgreSQL** e **Redis**: sem portas no host (apenas rede interna Podman)
- **Volumes nomeados** para dados persistentes (`pg_data`, `redis_data`, `bundle_cache`)

### Middleware Stack (ordem de execução)

1. `CorsMiddleware` — valida origens permitidas, bloqueia OPTIONS não autorizadas
2. `RateLimitingMiddleware` — protege endpoints sensíveis (429 se excedido)
3. `AuthMiddleware` — valida JWT em rotas protegidas (401 se inválido)

---

## ⚡ Quick Start

### Pré-requisitos

- Docker + Docker Compose
- Ruby 3.3.11 (para desenvolvimento local)
- PostgreSQL 16 (para desenvolvimento local)
- Redis 7 (para desenvolvimento local)

### Com Docker (recomendado)

```bash
# 1. Configure as variáveis de ambiente
cp .env.example .env
# Edite .env com suas credenciais

# 2. Build e suba os containers
docker compose up -d --build

# 3. Crie o banco e seed admin
docker compose exec web bin/rails db:create db:migrate db:seed

# 4. Acesse
open http://localhost:8081
```

### Sem Docker (desenvolvimento local)

```bash
cp .env.example .env
# Ajuste DATABASE_HOST=127.0.0.1 e REDIS_URL=redis://127.0.0.1:6379/0

bundle install
bin/rails db:create db:migrate db:seed
bin/rails server -p 3001
```

Acesse: `http://localhost:3001`

---

## 📡 Endpoints da API

### Autenticação

| Método | Endpoint | Descrição | Auth |
|--------|----------|-----------|:----:|
| `POST` | `/users` | Cadastro de usuário | ❌ |
| `POST` | `/users/sign_in` | Login (retorna JWT) | ❌ |
| `DELETE` | `/users/sign_out` | Logout (blacklist do token) | ✅ |
| `POST` | `/users/confirm` | Confirmar email com código | ❌ |
| `POST` | `/users/confirm/resend` | Reenviar código de confirmação | ❌ |
| `POST` | `/passwords` | Esqueci minha senha | ❌ |
| `PATCH/PUT` | `/passwords` | Resetar senha com token | ❌ |
| `POST` | `/tokens/verify` | Verificar validade do JWT | ❌* |

### Admin (requer role: admin)

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `GET` | `/users` | Listar todos os usuários |
| `DELETE` | `/users/:id` | Remover um usuário |
| `GET` | `/admin/stats` | Estatísticas do dashboard |
| `POST` | `/admin/passwords/initiate` | Iniciar reset admin (dual-code) |
| `POST` | `/admin/passwords/reset` | Resetar senha admin |

### OAuth

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `GET` | `/auth/google_oauth2/callback` | Login com Google |
| `GET` | `/auth/apple/callback` | Login com Apple |

### Health

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `GET` | `/up` | Health check do Rails |

> **Nota:** Todos os endpoints também funcionam com prefixo `/api/` (ex: `/api/users/sign_in`) para compatibilidade com frontends que prefixam `/api`.

📖 **Documentação detalhada**: [API_DOCS.md](API_DOCS.md)
📖 **Fluxo completo**: [FLOW.md](FLOW.md)

---

## 🔐 Segurança

- ✅ **JWT Stateless** com expiração de 24h (HS256)
- ✅ **Blacklist de tokens** via Redis no logout
- ✅ **bcrypt** via `has_secure_password`
- ✅ **Confirmação de email** obrigatória antes do login
- ✅ **Rate limiting** por IP (5/min login, 3/min resend, 2/min forgot)
- ✅ **Mensagens genéricas** em erros (não enumera emails existentes)
- ✅ **CORS** com origens permitidas (localhost, duckdns.org)
- ✅ **Sanitização global** de erros (sem stack trace)
- ✅ **Container não-root** no Docker

---

## 🔧 Variáveis de Ambiente

| Variável | Descrição | Obrigatório | Padrão |
|----------|-----------|:-----------:|--------|
| `SECRET_KEY_BASE` | Chave de sessão Rails | ✅ | — |
| `JWT_SECRET` | Chave para assinar tokens JWT | ✅ | — |
| `DATABASE_HOST` | Host do PostgreSQL | ✅ | `127.0.0.1` |
| `DATABASE_PORT` | Porta do PostgreSQL | | `5432` |
| `DATABASE_NAME` | Nome do banco | ✅ | `auth_dev_db` |
| `DATABASE_USER` | Usuário do banco | ✅ | `auth_dev` |
| `DATABASE_PASSWORD` | Senha do banco | ✅ | — |
| `REDIS_URL` | URL do Redis | ✅ | `redis://redis:6379/0` |
| `SMTP_HOST` | Servidor SMTP | ✅ | `smtp.gmail.com` |
| `SMTP_PORT` | Porta SMTP | | `587` |
| `SMTP_USER` | Usuário SMTP | ✅ | — |
| `SMTP_PASS` | Senha SMTP | ✅ | — |
| `ADMIN_EMAIL` | Email do admin padrão | | `admin@admin.com` |
| `ADMIN_PASSWORD` | Senha do admin padrão | | `admin123456` |
| `DOMAIN_HOST` | Domínio (links em emails) | | `localhost` |
| `DOMAIN_PORT` | Porta do domínio | | `3001` |
| `EMAIL_FROM` | Remetente de emails | | `labonosp@gmail.com` |

> Configure em `.env` (copie de `.env.example`). **Nunca commite o `.env`**.

---

## 🧪 Testes

### RSpec

```bash
# Certifique-se de Redis estar rodando
bin/rails spec
# Ou específico:
bin/rails spec spec/requests/auth_spec.rb
```

### Minitest

```bash
bin/rails test test/requests/auth_test.rb
```

**Cobertura:**
- ✅ Registro (sucesso, duplicata, senhas divergentes, campos faltando)
- ✅ Login (sem confirmação, confirmado, senha errada)
- ✅ Confirmação de email (código correto/incorreto/com espaços)
- ✅ Rotas protegidas (sem token, token inválido, expirado, sem Bearer)
- ✅ Forgot/reset password (fluxo completo)
- ✅ Logout (blacklist do token)
- ✅ CORS (preflight OPTIONS, POST com Origin)
- ✅ Rate limiting (login, resend, forgot, health check)
- ✅ Full E2E flow (registro → confirmação → login → forgot → reset → logout)

---

## 🚢 Deploy

### Docker (production-like)

```bash
docker compose up -d --build
```

Acesse: `http://localhost:8081`

### Kamal (servidor remoto)

1. Configure `config/deploy.yml` (servidor, registry, env vars)
2. Configure `.kamal/secrets`
3. Execute:

```bash
bin/kamal setup
bin/kamal deploy
```

---

## 📁 Estrutura do Projeto

```
├── app/
│   ├── controllers/          # Auth, sessions, passwords, admin, OAuth
│   ├── models/               # User (has_secure_password, enum roles)
│   ├── mailers/              # UserMailer, AdminResetMailer
│   └── views/                # Templates de email
├── lib/
│   ├── auth_middleware.rb    # Validação JWT
│   ├── cors_middleware.rb    # Controle de CORS
│   └── rate_limiting_middleware.rb  # Rate limit por IP
├── config/
│   ├── routes.rb             # Mapa de rotas (/api e diretas)
│   ├── deploy.yml            # Config Kamal
│   ├── initializers/
│   │   ├── jwt.rb            # Config JWT (HS256, 24h)
│   │   └── middleware.rb     # Stack de middleware
│   └── environments/         # Rails env configs
├── db/
│   ├── migrate/              # Migrations (admin_reset, OAuth, etc.)
│   └── seeds.rb              # Cria admin inicial
├── public/
│   ├── index.html            # Landing page
│   └── auth/                 # Admin panel (HTML/JS/CSS)
├── spec/                     # Testes RSpec
├── test/                     # Testes Minitest
├── podman-compose.yml        # Caddy + Rails + PG + Redis
├── Dockerfile                # Multi-stage build
└── .github/workflows/ci.yml  # CI: Brakeman, audit, RuboCop
```

---

## 📚 Documentação

- [API_DOCS.md](API_DOCS.md) — Documentação completa da API com exemplos
- [FLOW.md](FLOW.md) — Fluxo de autenticação passo a passo
- [HEALTH_REPORT.md](HEALTH_REPORT.md) — Status de saúde do serviço

---

## 📄 Licença

Proprietário — LABONO
