COMPOSE			=	docker compose
COMPOSE_FILE	=	srcs/docker-compose.yml
ENV_FILE		=	srcs/.env
DATA_PATH		=	/home/mel-houa/data

.PHONY: all up down clean fclean re logs ps prune

all: up

up:
	@sudo  mkdir -p $(DATA_PATH)/mariadb
	@sudo  mkdir -p $(DATA_PATH)/wordpress
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up --build -d

down:
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down

clean:
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down --rmi all --volumes

fclean: clean
	@sudo rm -rf $(DATA_PATH)
	@echo "Removed $(DATA_PATH)"

re: fclean
	@$(MAKE) all

logs:
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) logs -f

ps:
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) ps

prune:
	@docker system prune -af