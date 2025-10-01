logs:
	docker compose logs -f n8n

ps:
	docker compose ps

restart:
	docker compose restart

down:
	docker compose down

update:
	docker compose pull n8n
	docker compose up -d n8n

setup:
	./setup-interactive.sh

start:
	docker compose up -d