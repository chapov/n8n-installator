#!/bin/bash

# Скрипт для первоначальной настройки SSL сертификатов Let's Encrypt для n8n

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Инициализация SSL сертификатов Let's Encrypt${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Загрузка переменных окружения
if [ ! -f .env ]; then
    echo -e "${RED}Ошибка: Файл .env не найден!${NC}"
    echo -e "${YELLOW}Скопируйте .env.example в .env и настройте его перед запуском.${NC}"
    exit 1
fi

source .env

# Проверка обязательных переменных
if [ -z "$N8N_DOMAIN" ]; then
    echo -e "${RED}Ошибка: N8N_DOMAIN не установлен в .env${NC}"
    exit 1
fi

if [ -z "$SSL_EMAIL" ]; then
    echo -e "${RED}Ошибка: SSL_EMAIL не установлен в .env${NC}"
    exit 1
fi

echo -e "${YELLOW}Домен: ${NC}$N8N_DOMAIN"
echo -e "${YELLOW}Email: ${NC}$SSL_EMAIL"
echo ""

# Проверка, что домен резолвится на этот сервер
echo -e "${YELLOW}Проверка DNS записи для $N8N_DOMAIN...${NC}"
DOMAIN_IP=$(dig +short $N8N_DOMAIN | tail -n1)
if [ -z "$DOMAIN_IP" ]; then
    echo -e "${RED}Внимание: Домен $N8N_DOMAIN не резолвится!${NC}"
    echo -e "${YELLOW}Убедитесь, что DNS запись указывает на этот сервер перед продолжением.${NC}"
    read -p "Продолжить все равно? (yes/no): " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
        exit 1
    fi
else
    echo -e "${GREEN}DNS запись найдена: $DOMAIN_IP${NC}"
fi
echo ""

# Создание директорий
echo -e "${YELLOW}Создание необходимых директорий...${NC}"
mkdir -p ./certbot/conf
mkdir -p ./certbot/www
mkdir -p ./nginx/conf.d
mkdir -p ./local-files

# Создание временной nginx конфигурации для получения сертификата
echo -e "${YELLOW}Создание временной конфигурации nginx...${NC}"
cat > ./nginx/conf.d/n8n-temp.conf << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name N8N_DOMAIN_PLACEHOLDER;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 200 'OK - Waiting for SSL certificate';
        add_header Content-Type text/plain;
    }
}
EOF

# Замена плейсхолдера на реальный домен
sed -i "s/N8N_DOMAIN_PLACEHOLDER/$N8N_DOMAIN/g" ./nginx/conf.d/n8n-temp.conf

# Временно переименовываем основную конфигурацию n8n
echo -e "${YELLOW}Временное отключение основной конфигурации n8n...${NC}"
if [ -f "./nginx/conf.d/n8n.conf" ]; then
    mv ./nginx/conf.d/n8n.conf ./nginx/conf.d/n8n.conf.backup
fi

# Запуск только nginx для получения сертификата
echo -e "${YELLOW}Запуск nginx для получения SSL сертификата...${NC}"
docker compose up -d nginx

echo -e "${YELLOW}Ожидание запуска nginx...${NC}"
sleep 5

# Получение сертификата
echo -e "${YELLOW}Запрос SSL сертификата от Let's Encrypt...${NC}"
docker run --rm \
    -v $(pwd)/certbot/conf:/etc/letsencrypt \
    -v $(pwd)/certbot/www:/var/www/certbot \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $SSL_EMAIL \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d $N8N_DOMAIN

if [ $? -eq 0 ]; then
    echo -e "${GREEN}SSL сертификат успешно получен!${NC}"
    
    # Удаление временной конфигурации
    echo -e "${YELLOW}Удаление временной конфигурации...${NC}"
    rm -f ./nginx/conf.d/n8n-temp.conf
    
    # Восстановление основной конфигурации n8n
    echo -e "${YELLOW}Восстановление основной конфигурации n8n...${NC}"
    if [ -f "./nginx/conf.d/n8n.conf.backup" ]; then
        mv ./nginx/conf.d/n8n.conf.backup ./nginx/conf.d/n8n.conf
    fi
    
    # Остановка временного nginx
    echo -e "${YELLOW}Остановка временного nginx...${NC}"
    docker compose down
    
    # Запуск всех сервисов
    echo -e "${GREEN}Запуск всех сервисов n8n...${NC}"
    docker compose up -d
    
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}Установка завершена успешно!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${GREEN}n8n доступен по адресу: https://$N8N_DOMAIN${NC}"
    echo ""
    echo -e "${YELLOW}Полезные команды:${NC}"
    echo -e "  docker compose logs -f n8n     - просмотр логов n8n"
    echo -e "  docker compose ps              - статус контейнеров"
    echo -e "  docker compose restart         - перезапуск всех сервисов"
    echo -e "  docker compose down            - остановка всех сервисов"
    echo ""
    echo -e "${YELLOW}Сертификат будет автоматически обновляться каждые 12 часов.${NC}"
    echo ""
else
    echo -e "${RED}Ошибка при получении SSL сертификата!${NC}"
    echo -e "${YELLOW}Убедитесь, что:${NC}"
    echo -e "  1. Домен $N8N_DOMAIN указывает на этот сервер"
    echo -e "  2. Порты 80 и 443 открыты в файрволе"
    echo -e "  3. На портах 80 и 443 не запущены другие сервисы"
    echo ""
    
    # Восстановление основной конфигурации даже при ошибке
    if [ -f "./nginx/conf.d/n8n.conf.backup" ]; then
        mv ./nginx/conf.d/n8n.conf.backup ./nginx/conf.d/n8n.conf
    fi
    
    docker compose down
    exit 1
fi

