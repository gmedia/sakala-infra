COMPOSE := docker compose -f docker-compose.yml

.PHONY: up down restart logs network doctor reset config test-runtime railpack-sandbox full-stack-env full-stack-agent-env

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

test-runtime:
	./scripts/test-runtime-route.sh

railpack-sandbox:
	./scripts/full-stack-env.sh railpack-sandbox

full-stack-env:
	./scripts/full-stack-env.sh

full-stack-agent-env:
	./scripts/full-stack-env.sh agent
