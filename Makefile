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
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down --rmi all

fclean: clean
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down --volumes
	@sudo rm -rf $(DATA_PATH)
	@echo "Removed $(DATA_PATH)"

re: fclean
	@$(MAKE) all

logs:
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) logs -f

ps:
	@$(COMPOSE) --env-file $(ENV_FILE) -f $(COMPOSE_FILE) ps

prune:
	@echo "This will remove ALL unused Docker images, containers, networks and build cache system-wide."
	@echo "Type 'yes' to continue, or anything else to abort."
	@read -r answer; if [ "$$answer" = "yes" ]; then docker system prune -af; else echo "Aborted."; fi