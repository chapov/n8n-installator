#!/bin/bash

# Скрипт установки n8n с SSL через curl
# Использование: curl -fsSL https://raw.githubusercontent.com/chapov/n8n-installator/main/install.sh | bash

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Установка n8n с SSL от Let's Encrypt${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Проверка, что мы на Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    echo -e "${RED}Этот скрипт поддерживает только Ubuntu!${NC}"
    echo -e "${YELLOW}Установите n8n вручную для вашей системы.${NC}"
    exit 1
fi

# Проверка прав sudo
if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}Для установки требуются права sudo.${NC}"
    echo -e "${YELLOW}Введите пароль при запросе.${NC}"
    echo ""
fi

# Создание временной директории
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}Создание временной директории: ${TEMP_DIR}${NC}"

# Функция очистки при выходе
cleanup() {
    echo -e "${YELLOW}Очистка временных файлов...${NC}"
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Клонирование репозитория
echo -e "${YELLOW}Клонирование репозитория n8n...${NC}"
cd "$TEMP_DIR"

# Проверка наличия git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Установка git...${NC}"
    sudo apt-get update
    sudo apt-get install -y git
fi

# Клонирование
REPO_URL="https://github.com/chapov/n8n-installator.git"
echo -e "${BLUE}Клонирование из: ${REPO_URL}${NC}"

if ! git clone "$REPO_URL" n8n-ssl-installer; then
    echo -e "${RED}Ошибка клонирования репозитория!${NC}"
    echo -e "${YELLOW}Проверьте URL репозитория и доступность интернета.${NC}"
    exit 1
fi

cd n8n-ssl-installer

# Проверка наличия интерактивного скрипта
if [ ! -f "setup-interactive.sh" ]; then
    echo -e "${RED}Файл setup-interactive.sh не найден в репозитории!${NC}"
    exit 1
fi

# Делаем скрипт исполняемым
chmod +x setup-interactive.sh

echo -e "${GREEN}Репозиторий успешно клонирован!${NC}"
echo ""

# Запуск интерактивного скрипта
echo -e "${YELLOW}Запуск интерактивного скрипта установки...${NC}"
echo -e "${BLUE}Следуйте инструкциям на экране.${NC}"
echo ""

# Запуск с принудительной интерактивностью
./setup-interactive.sh

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Установка завершена!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${YELLOW}Временные файлы будут удалены автоматически.${NC}"
echo -e "${YELLOW}n8n установлен в текущей директории.${NC}"
echo ""
echo -e "${BLUE}Полезные команды:${NC}"
echo -e "  cd n8n-ssl-installer"
echo -e "  docker compose logs -f n8n     - просмотр логов"
echo -e "  docker compose ps              - статус контейнеров"
echo -e "  docker compose restart         - перезапуск"
echo -e "  docker compose down            - остановка"
echo ""
