# 🏗️ Infinity IT Solutions - Infrastructure

Infraestrutura Docker centralizada para todos os projetos (PostgreSQL, Redis, Nginx com SSL).

## 📦 Serviços

| Serviço | Container | Porta | Descrição |
|---------|-----------|-------|-----------|
| **PostgreSQL** | postgres-db | 5432 | Banco de dados |
| **Redis** | redis-cache | 6379 | Cache e filas |
| **Nginx** | nginx-proxy | 80, 443 | Proxy reverso com SSL |
| **Certbot** | certbot | - | Renovação automática SSL |

## 🌐 Domínios

| Subdomínio | Destino |
|------------|---------|
| `personalweb.infinityitsolutions.com.br` | Frontend (porta 3000) |
| `personalapi.infinityitsolutions.com.br` | Backend API (porta 3001) |

---

## 🚀 Deploy Completo (VPS)

### Ordem de execução

```
1. Infrastructure (este repo) → Cria rede + PostgreSQL + Redis + Nginx
2. Backend → Conecta na rede
3. Frontend → Conecta na rede
```

### Passo 1: Infraestrutura

```bash
# Clonar repositório
cd ~
git clone https://github.com/douglassleite/infrastructure_infinitysolutions.git
cd infrastructure_infinitysolutions

# Configurar variáveis
cp .env.example .env
nano .env  # Editar senhas

# Criar diretórios necessários
mkdir -p certbot/conf certbot/www nginx/conf.d

# Copiar config inicial do nginx (sem SSL)
cp nginx/conf.d/default.conf.nossl nginx/conf.d/default.conf

# Subir serviços
docker compose up -d

# Verificar
docker ps
```

### Passo 2: Backend

```bash
cd ~
git clone https://github.com/douglassleite/personal_trainer_backend.git
cd personal_trainer_backend

# Configurar variáveis
cp .env.example .env
nano .env  # Editar

# Build e executar
docker compose up -d --build

# Executar migrations
docker exec personal-trainer-backend npx prisma migrate deploy
```

### Passo 3: Frontend

```bash
cd ~
git clone https://github.com/douglassleite/personal_trainer_web.git
cd personal_trainer_web

# Build e executar
docker compose -f docker-compose.prod.yml up -d --build
```

### Passo 4: SSL (Certbot)

```bash
cd ~/infrastructure_infinitysolutions

# Gerar certificados
docker run -it --rm \
  -v $(pwd)/certbot/conf:/etc/letsencrypt \
  -v $(pwd)/certbot/www:/var/www/certbot \
  certbot/certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  -d personalweb.infinityitsolutions.com.br \
  -d personalapi.infinityitsolutions.com.br \
  --email seu-email@exemplo.com \
  --agree-tos --no-eff-email

# Ativar configuração SSL
cp nginx/conf.d/default.conf.ssl nginx/conf.d/default.conf
docker restart nginx-proxy

# Testar HTTPS
curl https://personalapi.infinityitsolutions.com.br/health
```

---

## 🔧 Variáveis de Ambiente

### Arquivo `.env`

```env
# PostgreSQL
POSTGRES_USER=personal_trainer
POSTGRES_PASSWORD=SENHA_SEGURA_AQUI
POSTGRES_DB=personal_trainer_db

# Redis
REDIS_PASSWORD=SENHA_REDIS_AQUI
```

> ⚠️ **Importante:** Use senhas fortes em produção!

---

## 🔄 Comandos Úteis

### Status dos containers

```bash
docker ps
```

### Logs

```bash
# Nginx
docker logs -f nginx-proxy

# PostgreSQL
docker logs -f postgres-db

# Redis
docker logs -f redis-cache
```

### Reiniciar serviços

```bash
# Todos
docker compose restart

# Individual
docker restart nginx-proxy
docker restart postgres-db
```

### Parar tudo

```bash
docker compose down
```

### Atualizar após mudanças

```bash
git pull origin master
docker compose up -d
```

---

## 🔒 Renovar Certificados SSL

Os certificados Let's Encrypt expiram em 90 dias.

### Renovação manual

```bash
cd ~/infrastructure_infinitysolutions

docker run -it --rm \
  -v $(pwd)/certbot/conf:/etc/letsencrypt \
  -v $(pwd)/certbot/www:/var/www/certbot \
  certbot/certbot renew

docker restart nginx-proxy
```

### Renovação automática (cron)

```bash
# Editar crontab
crontab -e

# Adicionar (renova todo dia 1 às 3h)
0 3 1 * * cd ~/infrastructure_infinitysolutions && docker run --rm -v $(pwd)/certbot/conf:/etc/letsencrypt -v $(pwd)/certbot/www:/var/www/certbot certbot/certbot renew && docker restart nginx-proxy
```

---

## 🌐 Rede Docker

Todos os serviços usam a rede `personal-trainer-network`:

| Serviço | Hostname interno |
|---------|------------------|
| PostgreSQL | `postgres-db` |
| Redis | `redis-cache` |
| Backend | `personal-trainer-backend` |
| Frontend | `personal-trainer-web` |

O backend e frontend conectam como `external: true` em seus docker-compose.

---

## 📁 Estrutura de Arquivos

```
infrastructure_infinitysolutions/
├── docker-compose.yml          # Definição dos serviços
├── .env                        # Variáveis (não commitar!)
├── .env.example                # Template de variáveis
├── nginx/
│   ├── nginx.conf              # Config principal
│   └── conf.d/
│       ├── default.conf        # Config ativa
│       ├── default.conf.nossl  # Sem SSL (para gerar cert)
│       └── default.conf.ssl    # Com SSL (produção)
└── certbot/
    ├── conf/                   # Certificados SSL
    └── www/                    # Desafio ACME
```

---

## 🐛 Troubleshooting

### Nginx não inicia (host not found)

```bash
# Verificar se backend/frontend estão na rede
docker network inspect personal-trainer-network

# Usar config nossl temporariamente
cp nginx/conf.d/default.conf.nossl nginx/conf.d/default.conf
docker restart nginx-proxy
```

### PostgreSQL não conecta

```bash
# Verificar se está rodando
docker ps | grep postgres

# Testar conexão
docker exec -it postgres-db psql -U personal_trainer -d personal_trainer_db
```

### Certificado SSL inválido

```bash
# Verificar se existe
ls -la certbot/conf/live/

# Regenerar se necessário
docker run -it --rm \
  -v $(pwd)/certbot/conf:/etc/letsencrypt \
  -v $(pwd)/certbot/www:/var/www/certbot \
  certbot/certbot delete --cert-name personalweb.infinityitsolutions.com.br

# Depois gerar novamente (ver passo 4)
```

---

## 📄 Licença

Proprietário - Todos os direitos reservados.
