# Wedding Sites - Deploy de Sites Individuais

Esta pasta contém os sites de casamento deployados como containers separados.

## Estrutura

```
wedding-sites/
├── deploy-site.sh          # Script de deploy automático
├── README.md               # Este arquivo
└── vanessaemarlo/          # Exemplo de site
    ├── Dockerfile
    ├── docker-compose.yml
    ├── nginx.conf
    └── site/               # Arquivos do site (HTML, CSS, JS)
```

## Como fazer deploy de um novo site

### 1. Usar o script automático

```bash
cd infrastructure_infinitysolutions/wedding-sites

# Sintaxe: ./deploy-site.sh <nome-do-site> <caminho-do-modelo>
./deploy-site.sh nomedocasal /path/to/evolly/src/custom-sites/nomedocasal/modelo-X
```

### 2. Configurar o nginx principal

Adicione no arquivo `nginx/conf.d/default.conf`:

```nginx
# Adicionar upstream (junto com os outros upstreams no início do arquivo)
upstream nomedocasal {
    server wedding-nomedocasal:80;
    keepalive 32;
}

# Adicionar no bloco de redirecionamento HTTP (linha ~30)
server_name ... nomedocasal.com.br www.nomedocasal.com.br;

# Adicionar bloco HTTPS (no final do arquivo)
server {
    listen 443 ssl http2;
    server_name www.nomedocasal.com.br;

    ssl_certificate /etc/letsencrypt/live/nomedocasal.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nomedocasal.com.br/privkey.pem;

    return 301 https://nomedocasal.com.br$request_uri;
}

server {
    listen 443 ssl http2;
    server_name nomedocasal.com.br;

    ssl_certificate /etc/letsencrypt/live/nomedocasal.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nomedocasal.com.br/privkey.pem;

    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    add_header Strict-Transport-Security "max-age=63072000" always;

    location / {
        limit_req zone=web burst=100 nodelay;
        proxy_pass http://nomedocasal;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 60s;
    }

    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot|html)$ {
        proxy_pass http://nomedocasal;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_valid 200 30d;
        add_header Cache-Control "public, immutable, max-age=2592000";
    }

    location /health {
        proxy_pass http://nomedocasal/health;
        access_log off;
    }
}
```

### 3. Gerar certificado SSL

```bash
# Primeiro, usar config sem SSL para validação do certbot
cp nginx/conf.d/default.conf.nossl nginx/conf.d/default.conf
./manage.sh restart-nginx

# Gerar certificado
docker exec -it nginx-proxy certbot certonly --webroot \
  -w /var/www/certbot \
  -d nomedocasal.com.br \
  -d www.nomedocasal.com.br \
  --email seu@email.com \
  --agree-tos \
  --no-eff-email

# Restaurar config com SSL
# (editar default.conf manualmente ou copiar de backup)
./manage.sh restart-nginx
```

### 4. Reiniciar nginx

```bash
./manage.sh restart-nginx
```

## Comandos úteis

```bash
# Ver status do container
docker ps | grep wedding-

# Ver logs
docker logs wedding-nomedocasal -f

# Rebuild após atualizar arquivos
cd wedding-sites/nomedocasal
docker compose build && docker compose up -d

# Parar site
cd wedding-sites/nomedocasal
docker compose down

# Remover completamente
cd wedding-sites
rm -rf nomedocasal
docker rm -f wedding-nomedocasal
```

## Arquitetura

```
                    ┌─────────────────┐
                    │   Cloudflare    │
                    │   ou DNS        │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  nginx-proxy    │
                    │  (SSL termination)
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼───────┐   ┌───────▼───────┐   ┌───────▼───────┐
│    evolly     │   │    evolly-    │   │    evolly-    │
│    -models    │   │ vanessaemarlo │   │  nomedocasal  │
│   (admin)     │   │   (site)      │   │    (site)     │
│   :8004       │   │    :80        │   │     :80       │
└───────────────┘   └───────┬───────┘   └───────────────┘
                            │
                    ┌───────▼───────┐
                    │  Chamadas API │
                    │  /api/* ──────┼──► evolly:8004
                    └───────────────┘
```

Cada site de casamento:
- Roda em container separado (nginx:alpine)
- Serve apenas arquivos estáticos
- Faz proxy de `/api/*` para o backend (Evolly)
- Domínio próprio com SSL

## Sites ativos

| Site | Domínio | Container |
|------|---------|-----------|
| vanessaemarlo | vanessaemarlo.com.br | evolly-vanessaemarlo |
