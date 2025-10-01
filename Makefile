# Makefile для n8n SSL установки

.PHONY: help install setup clean logs status restart stop update

# Цвета для вывода
GREEN=\033[0;32m
YELLOW=\033[1;33m
NC=\033[0m

help: ## Показать справку
	@echo "$(GREEN)n8n SSL Installer - Доступные команды:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Примеры использования:$(NC)"
	@echo "  make install    # Установка через curl"
	@echo "  make setup      # Интерактивная настройка"
	@echo "  make logs       # Просмотр логов n8n"

install: ## Установка через curl (замените USER/REPO на ваш репозиторий)
	@echo "$(GREEN)Установка n8n через curl...$(NC)"
	@echo "$(YELLOW)Замените USER/REPO на ваш GitHub репозиторий!$(NC)"
	@echo ""
	@echo "curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | bash"

setup: ## Запуск интерактивного установщика
	@echo "$(GREEN)Запуск интерактивного установщика...$(NC)"
	@./setup-interactive.sh

clean: ## Очистка временных файлов и остановка сервисов
	@echo "$(GREEN)Остановка сервисов...$(NC)"
	@docker compose down
	@echo "$(GREEN)Очистка завершена.$(NC)"

logs: ## Просмотр логов n8n
	@echo "$(GREEN)Просмотр логов n8n...$(NC)"
	@docker compose logs -f n8n

logs-all: ## Просмотр логов всех сервисов
	@echo "$(GREEN)Просмотр логов всех сервисов...$(NC)"
	@docker compose logs -f

status: ## Проверка статуса контейнеров
	@echo "$(GREEN)Статус контейнеров:$(NC)"
	@docker compose ps

restart: ## Перезапуск всех сервисов
	@echo "$(GREEN)Перезапуск сервисов...$(NC)"
	@docker compose restart

stop: ## Остановка всех сервисов
	@echo "$(GREEN)Остановка сервисов...$(NC)"
	@docker compose down

start: ## Запуск всех сервисов
	@echo "$(GREEN)Запуск сервисов...$(NC)"
	@docker compose up -d

update: ## Обновление n8n до последней версии
	@echo "$(GREEN)Обновление n8n...$(NC)"
	@docker compose pull n8n
	@docker compose up -d n8n
	@echo "$(GREEN)Обновление завершено.$(NC)"

backup: ## Создание резервной копии данных
	@echo "$(GREEN)Создание резервной копии...$(NC)"
	@mkdir -p backups
	@docker compose exec postgres pg_dump -U n8n n8n > backups/n8n_backup_$(shell date +%Y%m%d_%H%M%S).sql 2>/dev/null || echo "$(YELLOW)PostgreSQL не запущен, пропускаем бэкап БД$(NC)"
	@docker run --rm -v n8n_n8n_data:/data -v $(PWD)/backups:/backup alpine tar czf /backup/n8n_data_$(shell date +%Y%m%d_%H%M%S).tar.gz -C /data . 2>/dev/null || echo "$(YELLOW)Volume n8n не найден$(NC)"
	@echo "$(GREEN)Резервная копия создана в директории backups/$(NC)"

restore: ## Восстановление из резервной копии (укажите файл: make restore FILE=backup.sql)
	@if [ -z "$(FILE)" ]; then \
		echo "$(YELLOW)Укажите файл для восстановления: make restore FILE=backup.sql$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Восстановление из $(FILE)...$(NC)"
	@docker compose exec -T postgres psql -U n8n n8n < $(FILE)
	@echo "$(GREEN)Восстановление завершено.$(NC)"

ssl-renew: ## Принудительное обновление SSL сертификата
	@echo "$(GREEN)Обновление SSL сертификата...$(NC)"
	@docker compose run --rm certbot renew
	@docker compose restart nginx
	@echo "$(GREEN)SSL сертификат обновлен.$(NC)"

info: ## Показать информацию о системе
	@echo "$(GREEN)Информация о системе:$(NC)"
	@echo "Docker версия: $(shell docker --version 2>/dev/null || echo 'Не установлен')"
	@echo "Docker Compose версия: $(shell docker compose version 2>/dev/null || echo 'Не установлен')"
	@echo "Операционная система: $(shell cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
	@echo "Архитектура: $(shell uname -m)"
	@echo "Пользователь: $(shell whoami)"
	@echo "Группы: $(shell groups)"