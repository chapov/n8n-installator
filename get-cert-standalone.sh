#!/bin/bash

# Альтернативный скрипт для получения SSL сертификата без Docker Compose
# Используется когда основной скрипт не работает

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Альтернативное получение SSL сертификата${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Загрузка переменных окружения
if [ ! -f .env ]; then
    echo -e "${RED}Ошибка: Файл .env не найден!${NC}"
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

# Создание директорий
mkdir -p ./certbot/conf
mkdir -p ./certbot/www

# Проверка, что порт 80 свободен
if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
    echo -e "${RED}Ошибка: Порт 80 занят!${NC}"
    echo -e "${YELLOW}Освободите порт 80 или остановите другие веб-серверы.${NC}"
    netstat -tlnp | grep ":80 "
    exit 1
fi

echo -e "${YELLOW}Получение SSL сертификата с помощью standalone режима...${NC}"

# Получение сертификата в standalone режиме
docker run --rm \
    -p 80:80 \
    -v $(pwd)/certbot/conf:/etc/letsencrypt \
    -v $(pwd)/certbot/www:/var/www/certbot \
    certbot/certbot certonly \
    --standalone \
    --email $SSL_EMAIL \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d $N8N_DOMAIN

if [ $? -eq 0 ]; then
    echo -e "${GREEN}SSL сертификат успешно получен!${NC}"
    echo ""
    echo -e "${GREEN}Теперь можете запустить все сервисы:${NC}"
    echo -e "${YELLOW}docker compose up -d${NC}"
    echo ""
else
    echo -e "${RED}Ошибка при получении SSL сертификата!${NC}"
    echo -e "${YELLOW}Убедитесь, что:${NC}"
    echo -e "  1. Домен $N8N_DOMAIN указывает на этот сервер"
    echo -e "  2. Порт 80 свободен"
    echo -e "  3. Файрвол не блокирует порт 80"
    exit 1
fi

