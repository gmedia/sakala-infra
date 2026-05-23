COMPOSE := docker compose -f docker-compose.yml

.PHONY: up down restart logs network doctor reset config

up:
	./scripts/up.sh

down:
	./scripts/down.sh

restart: down up

logs:
	$(COMPOSE) logs -f

network:
	./scripts/create-network.sh

doctor:
	./scripts/doctor.sh

reset:
	./scripts/reset-local.sh

config:
	$(COMPOSE) config
