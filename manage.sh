#!/bin/bash

# ===========================================
# Infinity IT Solutions - Comandos de Gerenciamento
# ===========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Diretório raiz baseado na localização do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
INFRA_DIR="$SCRIPT_DIR"
WEBSITE_DIR="$ROOT_DIR/website"
PERSONAL_DIR="$ROOT_DIR/apps/personal-trainer"

show_help() {
    echo ""
    echo -e "${BLUE}Infinity IT Solutions - Comandos de Gerenciamento${NC}"
    echo ""
    echo "Uso: ./manage.sh [comando]"
    echo ""
    echo "Comandos disponíveis:"
    echo ""
    echo -e "  ${GREEN}status${NC}          - Ver status de todos os containers"
    echo -e "  ${GREEN}logs${NC}            - Ver logs de todos os serviços"
    echo -e "  ${GREEN}logs-backend${NC}    - Ver logs do backend"
    echo -e "  ${GREEN}logs-web${NC}        - Ver logs do frontend"
    echo -e "  ${GREEN}logs-website${NC}    - Ver logs do site institucional"
    echo -e "  ${GREEN}logs-nginx${NC}      - Ver logs do nginx"
    echo ""
    echo -e "  ${GREEN}restart-backend${NC} - Reiniciar apenas o backend"
    echo -e "  ${GREEN}restart-web${NC}     - Reiniciar apenas o frontend"
    echo -e "  ${GREEN}restart-website${NC} - Reiniciar site institucional"
    echo -e "  ${GREEN}restart-nginx${NC}   - Reiniciar apenas o nginx"
    echo -e "  ${GREEN}restart-all${NC}     - Reiniciar todos os serviços"
    echo ""
    echo -e "  ${GREEN}update-backend${NC}  - Atualizar backend (git pull + rebuild)"
    echo -e "  ${GREEN}update-web${NC}      - Atualizar frontend (git pull + rebuild)"
    echo -e "  ${GREEN}update-website${NC}  - Atualizar site institucional"
    echo -e "  ${GREEN}update-all${NC}      - Atualizar todos"
    echo ""
    echo -e "  ${GREEN}db-shell${NC}        - Acessar PostgreSQL"
    echo -e "  ${GREEN}redis-shell${NC}     - Acessar Redis"
    echo -e "  ${GREEN}migrate${NC}         - Executar migrations do Prisma"
    echo ""
    echo -e "  ${GREEN}ssl-init${NC}        - Gerar certificados SSL (primeira vez)"
    echo -e "  ${GREEN}ssl-renew${NC}       - Renovar certificado SSL"
    echo -e "  ${GREEN}ssl-status${NC}      - Ver status do certificado SSL"
    echo ""
    echo -e "  ${GREEN}cleanup${NC}         - Limpar imagens e containers não utilizados"
    echo -e "  ${GREEN}disk${NC}            - Ver uso de disco do Docker"
    echo ""
}

case "$1" in
    status)
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    
    logs)
        docker logs -f --tail 100 personal-trainer-backend &
        docker logs -f --tail 100 personal-trainer-web &
        docker logs -f --tail 100 nginx-proxy
        ;;
    
    logs-backend)
        docker logs -f --tail 200 personal-trainer-backend
        ;;
    
    logs-web)
        docker logs -f --tail 200 personal-trainer-web
        ;;
    
    logs-nginx)
        docker logs -f --tail 200 nginx-proxy
        ;;
    
    logs-website)
        docker logs -f --tail 200 infinity-website
        ;;
    
    restart-backend)
        echo -e "${BLUE}Reiniciando backend Personal Trainer...${NC}"
        cd $PERSONAL_DIR/backend
        docker-compose -f docker-compose.prod.yml restart
        echo -e "${GREEN}Backend reiniciado${NC}"
        ;;
    
    restart-web)
        echo -e "${BLUE}Reiniciando frontend Personal Trainer...${NC}"
        cd $PERSONAL_DIR/web
        docker-compose -f docker-compose.prod.yml restart
        echo -e "${GREEN}Frontend reiniciado${NC}"
        ;;
    
    restart-nginx)
        echo -e "${BLUE}Reiniciando Nginx...${NC}"
        cd $INFRA_DIR
        docker-compose restart nginx
        echo -e "${GREEN}Nginx reiniciado${NC}"
        ;;
    
    restart-website)
        echo -e "${BLUE}Reiniciando site institucional...${NC}"
        cd $INFRA_DIR
        docker-compose restart infinity-website
        echo -e "${GREEN}Site institucional reiniciado${NC}"
        ;;
    
    restart-all)
        echo -e "${BLUE}Reiniciando todos os serviços...${NC}"
        cd $PERSONAL_DIR/backend && docker-compose -f docker-compose.prod.yml restart
        cd $PERSONAL_DIR/web && docker-compose -f docker-compose.prod.yml restart
        cd $INFRA_DIR && docker-compose restart
        echo -e "${GREEN}Todos os serviços reiniciados${NC}"
        ;;
    
    update-backend)
        echo -e "${BLUE}Atualizando backend Personal Trainer...${NC}"
        cd $PERSONAL_DIR/backend
        git pull
        docker-compose -f docker-compose.prod.yml build
        docker-compose -f docker-compose.prod.yml run --rm backend npx prisma migrate deploy
        docker-compose -f docker-compose.prod.yml up -d
        echo -e "${GREEN}Backend atualizado${NC}"
        ;;
    
    update-web)
        echo -e "${BLUE}Atualizando frontend Personal Trainer...${NC}"
        cd $PERSONAL_DIR/web
        git pull
        docker-compose -f docker-compose.prod.yml build
        docker-compose -f docker-compose.prod.yml up -d
        echo -e "${GREEN}Frontend atualizado${NC}"
        ;;
    
    update-website)
        echo -e "${BLUE}Atualizando site institucional...${NC}"
        cd $WEBSITE_DIR
        git pull
        cd $INFRA_DIR
        docker-compose build infinity-website
        docker-compose up -d infinity-website
        echo -e "${GREEN}Site institucional atualizado${NC}"
        ;;
    
    update-all)
        $0 update-backend
        $0 update-web
        $0 update-website
        ;;
    
    db-shell)
        docker exec -it postgres-db psql -U ${POSTGRES_USER:-personal_trainer} -d ${POSTGRES_DB:-personal_trainer_db}
        ;;
    
    redis-shell)
        docker exec -it redis-cache redis-cli
        ;;
    
    migrate)
        echo -e "${BLUE}Executando migrations...${NC}"
        cd $PERSONAL_DIR/backend
        docker-compose -f docker-compose.prod.yml run --rm backend npx prisma migrate deploy
        echo -e "${GREEN}Migrations executadas${NC}"
        ;;
    
    ssl-init)
        echo -e "${BLUE}Gerando certificados SSL...${NC}"
        cd $INFRA_DIR
        
        # Criar diretórios necessários
        mkdir -p certbot/conf certbot/www/.well-known/acme-challenge
        
        # Reiniciar nginx para garantir que está usando config HTTP
        echo -e "${YELLOW}Verificando configuração HTTP...${NC}"
        if [ -f nginx/conf.d/default.conf.nossl ]; then
            cp nginx/conf.d/default.conf.nossl nginx/conf.d/default.conf
            docker-compose restart nginx
            sleep 3
        fi
        
        # Verificar se nginx está rodando
        if ! docker ps | grep -q nginx-proxy; then
            echo -e "${RED}Nginx não está rodando. Iniciando...${NC}"
            docker-compose up -d nginx
            sleep 5
        fi
        
        # Usar docker run diretamente (evita entrypoint customizado do docker-compose)
        CERTBOT_CMD="docker run --rm \
            -v $INFRA_DIR/certbot/conf:/etc/letsencrypt \
            -v $INFRA_DIR/certbot/www:/var/www/certbot \
            certbot/certbot certonly --webroot \
            -w /var/www/certbot \
            --email contato@infinityitsolutions.com.br \
            --agree-tos \
            --no-eff-email \
            --non-interactive"
        
        echo -e "${YELLOW}Gerando certificado para www.infinityitsolutions.com.br...${NC}"
        $CERTBOT_CMD -d www.infinityitsolutions.com.br -d infinityitsolutions.com.br
        
        echo -e "${YELLOW}Gerando certificado para personalweb.infinityitsolutions.com.br...${NC}"
        $CERTBOT_CMD -d personalweb.infinityitsolutions.com.br
        
        echo -e "${YELLOW}Gerando certificado para personalapi.infinityitsolutions.com.br...${NC}"
        $CERTBOT_CMD -d personalapi.infinityitsolutions.com.br
        
        # Aguardar um pouco para o volume sincronizar
        sleep 2
        
        # Verificar se certificados foram gerados (verificar diretório local)
        if [ -d "certbot/conf/live/www.infinityitsolutions.com.br" ] || \
           [ -f "certbot/conf/renewal/www.infinityitsolutions.com.br.conf" ]; then
            echo -e "${GREEN}✓ Certificados gerados com sucesso!${NC}"
            
            # Aplicar configuração SSL
            if [ -f nginx/conf.d/default.conf.ssl ]; then
                echo -e "${YELLOW}Aplicando configuração SSL...${NC}"
                cp nginx/conf.d/default.conf.ssl nginx/conf.d/default.conf
                docker-compose restart nginx
                sleep 2
                echo -e "${GREEN}✓ HTTPS ativado!${NC}"
                echo ""
                echo -e "${GREEN}Sites disponíveis:${NC}"
                echo -e "  - https://www.infinityitsolutions.com.br"
                echo -e "  - https://personalweb.infinityitsolutions.com.br"
                echo -e "  - https://personalapi.infinityitsolutions.com.br"
            fi
        else
            echo -e "${YELLOW}! Certificados podem ter sido gerados no volume Docker.${NC}"
            echo -e "${YELLOW}  Aplicando configuração SSL de qualquer forma...${NC}"
            
            if [ -f nginx/conf.d/default.conf.ssl ]; then
                cp nginx/conf.d/default.conf.ssl nginx/conf.d/default.conf
                docker-compose restart nginx
                sleep 2
                
                # Testar se nginx iniciou corretamente
                if docker ps | grep -q nginx-proxy; then
                    echo -e "${GREEN}✓ HTTPS ativado com sucesso!${NC}"
                    echo ""
                    echo -e "${GREEN}Sites disponíveis:${NC}"
                    echo -e "  - https://www.infinityitsolutions.com.br"
                    echo -e "  - https://personalweb.infinityitsolutions.com.br"
                    echo -e "  - https://personalapi.infinityitsolutions.com.br"
                else
                    echo -e "${RED}✗ Nginx falhou ao iniciar. Voltando para HTTP...${NC}"
                    cp nginx/conf.d/default.conf.nossl nginx/conf.d/default.conf
                    docker-compose restart nginx
                fi
            fi
        fi
        ;;
    
    ssl-renew)
        echo -e "${BLUE}Renovando certificados SSL...${NC}"
        cd $INFRA_DIR
        docker run --rm \
            -v $INFRA_DIR/certbot/conf:/etc/letsencrypt \
            -v $INFRA_DIR/certbot/www:/var/www/certbot \
            certbot/certbot renew
        docker-compose restart nginx
        echo -e "${GREEN}Certificados renovados${NC}"
        ;;
    
    ssl-status)
        echo -e "${BLUE}Status do certificado SSL:${NC}"
        docker run --rm -v $INFRA_DIR/certbot/conf:/etc/letsencrypt certbot/certbot certificates
        ;;
    
    cleanup)
        echo -e "${YELLOW}Removendo containers parados e imagens não utilizadas...${NC}"
        docker system prune -f
        echo -e "${GREEN}Limpeza concluída${NC}"
        docker system df
        ;;
    
    disk)
        docker system df
        ;;
    
    *)
        show_help
        ;;
esac
