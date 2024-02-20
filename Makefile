.DEFAULT_GOAL := help

###
# CONSTANTS
###

ifneq (,$(findstring xterm,$(TERM)))
	BLACK   := $(shell tput -Txterm setaf 0)
	RED     := $(shell tput -Txterm setaf 1)
	GREEN   := $(shell tput -Txterm setaf 2)
	YELLOW  := $(shell tput -Txterm setaf 3)
	BLUE    := $(shell tput -Txterm setaf 4)
	MAGENTA := $(shell tput -Txterm setaf 5)
	CYAN    := $(shell tput -Txterm setaf 6)
	WHITE   := $(shell tput -Txterm setaf 7)
	RESET   := $(shell tput -Txterm sgr0)
else
	BLACK   := ""
	RED     := ""
	GREEN   := ""
	YELLOW  := ""
	BLUE    := ""
	MAGENTA := ""
	CYAN    := ""
	WHITE   := ""
	RESET   := ""
endif

HOST_USER_ID    := $(shell id --user)
HOST_USER_NAME  := $(shell id --user --name)
HOST_GROUP_ID   := $(shell id --group)
HOST_GROUP_NAME := $(shell id --group --name)

WEBSITE_DOMAIN  = demo.localhost
WEBSITE_URL     = https://$(WEBSITE_DOMAIN)

SERVICE_NAME = app
DOCKER_COMPOSE_FILE = docker-compose-development.yml

COMPOSER_SHARED_OPTIONS   = --ignore-platform-reqs --no-scripts --no-plugins --ansi --profile
COMPOSER_OPTIMIZE_OPTIONS = --optimize-autoloader --with-all-dependencies

DOCKER_COMPOSE_COMMAND       = @docker-compose
DOCKER_COMPOSE_EXEC          = $(DOCKER_COMPOSE_COMMAND) --file=$(DOCKER_COMPOSE_FILE) exec $(SERVICE_NAME)
DOCKER_COMPOSE_EXEC_AS_USER  = $(DOCKER_COMPOSE_COMMAND) --file=$(DOCKER_COMPOSE_FILE) exec --user=$(HOST_USER_NAME) $(SERVICE_NAME)

###
# FUNCTIONS
###

define taskDone
	@echo ""
	@echo " ${GREEN}✓${RESET}  ${GREEN}Task done!${RESET}"
	@echo ""
endef

# $(1)=NUMBER $(2)=TEXT
define orderedList
	@echo ""
	@echo " ${CYAN}$(1).${RESET}  ${CYAN}$(2)${RESET}"
	@echo ""
endef

# $(1)=TEXT $(2)=EXTRA
define showInfo
	@echo " ${YELLOW}ℹ${RESET}  $(1) $(2)"
endef

# $(1)=TEXT $(2)=EXTRA
define showAlert
	@echo " ${RED}!${RESET}  $(1) $(2)"
endef

# $(1)=CMD $(2)=OPTIONS
define runDockerCompose
	$(DOCKER_COMPOSE_COMMAND) $(1) $(2)
	$(call taskDone)
endef

# $(1)=CMD $(2)=OPTIONS
define runDockerComposeExec
	$(DOCKER_COMPOSE_EXEC) $(1) $(2)
	$(call taskDone)
endef

# $(1)=CMD $(2)=OPTIONS
define runDockerComposeExecAsUser
	$(DOCKER_COMPOSE_EXEC_AS_USER) $(1) $(2)
	$(call taskDone)
endef

###
# HELP
###

.PHONY: help
help:
	@clear
	@echo "╔══════════════════════════════════════════════════════════════════════════════╗"
	@echo "║                                                                              ║"
	@echo "║                           ${YELLOW}.:${RESET} AVAILABLE COMMANDS ${YELLOW}:.${RESET}                           ║"
	@echo "║                                                                              ║"
	@echo "╚══════════════════════════════════════════════════════════════════════════════╝"
	@echo ""
	@grep -E '^[a-zA-Z_0-9%-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "· ${YELLOW}%-30s${RESET} %s\n", $$1, $$2}'
	@echo ""

###
# MISCELANEOUS
###

require-%:
	@if [ -z "$($(*))" ] ; then \
		echo "" ; \
		echo " ${RED}⨉${RESET} Parameter [ ${BLINK}${*}${RESET} ] is required!" ; \
		echo "" ; \
		exit 1 ; \
	fi;
	
.PHONY: show-context
show-context: ## Setup: show context
	$(call showInfo,"Showing context")
	@echo ""
	@echo " · Host user : (${YELLOW}${HOST_USER_ID}${RESET}) ${YELLOW}${HOST_USER_NAME}${RESET}"
	@echo " · Host group: (${YELLOW}${HOST_GROUP_ID}${RESET}) ${YELLOW}${HOST_GROUP_NAME}${RESET}"
	@echo ""
	@echo " · Service:"
	@echo "   - ${YELLOW}${SERVICE_NAME}${RESET} (${CYAN}${DOCKER_COMPOSE_FILE}${RESET})"
	@echo ""
	@echo " · Domain:"
	@echo "   - ${YELLOW}${WEBSITE_URL}${RESET}"
	@echo ""
	@echo " · SSL:"
	@echo "   - Please execute ${YELLOW}make install-caddy-certificate${RESET} to install ${CYAN}Caddy's Root Certificate${RESET} on your browser"
	@echo ""
	$(call taskDone)

.PHONY: install-caddy-certificate
install-caddy-certificate: ## Setup: installs Caddy Local Authority certificate
	@echo "Installing [ $(YELLOW)Caddy Local Authority - 20XX ECC Root$(RESET) ] as a valid Certificate Authority"
	$(call orderedList,1,"Copy the root certificate from Caddy Docker container")
	@docker cp $(SERVICE_NAME):/data/caddy/pki/authorities/local/root.crt ./caddy-root-ca-authority.crt
	$(call orderedList,2,"Install the Caddy Authority certificate into your browser")
	@echo "$(YELLOW)Chrome-based browsers (Chrome, Brave, etc)$(RESET)"
	@echo "- Go to [ Settings / Privacy & Security / Security / Manage Certificates / Authorities ]"
	@echo "- Import [ ./caddy-root-ca-authority.crt ]"
	@echo "- Check on [ Trust this certificate for identifying websites ]"
	@echo "- Save changes"
	@echo ""
	@echo "$(YELLOW)Firefox browser$(RESET)"
	@echo "- Go to [ Settings / Privacy & Security / Security / Certificates / View Certificates / Authorities ]"
	@echo "- Import [ ./caddy-root-ca-authority.crt ]"
	@echo "- Check on [ This certificate can identify websites ]"
	@echo "- Save changes"
	@echo ""
	$(call showInfo,"For further information, please visit https://caddyserver.com/docs/running#docker-compose")
	$(call taskDone)

###
# DOCKER RELATED
###

.PHONY: build
build: ## Docker: builds the service
	$(call runDockerCompose,--file=$(DOCKER_COMPOSE_FILE) build,--build-arg="HOST_USER_ID=$(HOST_USER_ID)" --build-arg="HOST_USER_NAME=$(HOST_USER_NAME)" --build-arg="HOST_GROUP_ID=$(HOST_GROUP_ID)" --build-arg="HOST_GROUP_NAME=$(HOST_GROUP_NAME)")

.PHONY: up
up: ## Docker: starts the PHP-FPM service
	$(call runDockerCompose,--file=$(DOCKER_COMPOSE_FILE) up --remove-orphans --detach)

.PHONY: restart
restart: ## Docker: restarts the PHP-FPM service
	$(call runDockerCompose,--file=$(DOCKER_COMPOSE_FILE) restart $(SERVICE_NAME))

.PHONY: down
down: ## Docker: stops the service(s)
	$(call runDockerCompose,--file=$(DOCKER_COMPOSE_FILE) down --remove-orphans)

.PHONY: logs
logs: ## Docker: exposes the service logs
	$(call runDockerCompose,--file=$(DOCKER_COMPOSE_FILE) logs)

.PHONY: bash
bash: ## Docker: establish a bash session into main container
	$(call runDockerComposeExecAsUser,bash)

###
# SHARED
###

.PHONY: open-browser
open-browser: ## Application: opens the application domain with your preferred browser
	@echo "Opening the application domain with your preferred browser"
	$(call orderedList,1,"Make sure Caddy Authority certificate is installed on this browser")
	@echo "Execute $(YELLOW)make install-caddy-certificate$(RESET) and follow the guidelines"
	$(call orderedList,2,"Visit the application domain with your browser")
	@echo "Please execute $(YELLOW)x-www-browser $(WEBSITE_URL)$(RESET) in your terminal to open the browser"
	@echo ""
	$(call taskDone)

###
# APPLICATION
###

.PHONY: composer-dump
composer-dump: up ## Application: <composer dump-auto>
	$(call runDockerComposeExecAsUser,composer dump-auto --optimize,$(COMPOSER_SHARED_OPTIONS))

.PHONY: composer-install
composer-install: up ## Application: <composer install>
	$(call runDockerComposeExecAsUser,composer install --optimize-autoloader,$(COMPOSER_SHARED_OPTIONS))

.PHONY: composer-remove
composer-remove: up ## Application: <composer remove>
	$(call runDockerComposeExecAsUser,composer remove $(COMPOSER_OPTIMIZE_OPTIONS),$(COMPOSER_SHARED_OPTIONS))

.PHONY: composer-require-dev
composer-require-dev: up ## Application: <composer require --dev>
	$(call runDockerComposeExecAsUser,composer require $(COMPOSER_OPTIMIZE_OPTIONS) --dev,$(COMPOSER_SHARED_OPTIONS))

.PHONY: composer-require
composer-require: up ## Application: <composer require>
	$(call runDockerComposeExecAsUser,composer require $(COMPOSER_OPTIMIZE_OPTIONS),$(COMPOSER_SHARED_OPTIONS))

.PHONY: composer-update
composer-update: up ## Application: <composer update>
	$(call runDockerComposeExecAsUser,composer update $(COMPOSER_OPTIMIZE_OPTIONS),$(COMPOSER_SHARED_OPTIONS))

.PHONY: linter
linter: up ## Application: <composer linter>
	$(call runDockerComposeExecAsUser,composer linter)

.PHONY: phpcs
phpcs: up ## Application: <composer phpcbs>
	$(call runDockerComposeExecAsUser,composer phpcs)

.PHONY: phpcbf
phpcbf: up ## Application: <composer phpcbf>
	$(call runDockerComposeExecAsUser,composer phpcbf)

.PHONY: phpstan
phpstan: up ## Application: <composer phpstan>
	$(call runDockerComposeExecAsUser,composer phpstan)

.PHONY: phpinsights
phpinsights: up ## Application: <composer phpinsights>
	$(call runDockerComposeExecAsUser,composer phpinsights)

.PHONY: mutation
mutation: up ## Application: <composer test-mutation>
	$(call runDockerComposeExecAsUser,composer test-mutation)

.PHONY: paratest
paratest: up ## Application: <composer paratest>
	$(call runDockerComposeExecAsUser,composer paratest)

.PHONY: phpunit
phpunit: up ## Application: <composer test>
	$(call runDockerComposeExecAsUser,composer test)

.PHONY: tests
tests: up paratest mutation ## Application: runs ParaTest + Mutation

.PHONY: info
info: ## Application: displays the php.ini details
	$(call runDockerComposeExecAsUser,php -i)
	
###
# PRODUCTION
###

.PHONY: up-production
up-production: down down-production ## Docker: starts the PRODUCTION service
	@docker build --target=build-production --tag app:production .
	$(call runDockerCompose,--file=docker-compose-production.yml up --detach)
	@echo " · Domain:"
	@echo "   - ${YELLOW}${WEBSITE_URL}${RESET}"
	@echo ""
	@echo " · SSL:"
	@echo "   - Please execute ${YELLOW}make install-caddy-certificate${RESET} to install ${CYAN}Caddy's Root Certificate${RESET} on your browser"
	$(call taskDone)

.PHONY: down-production
down-production: ## Docker: stops the PRODUCTION service
	$(call runDockerCompose,--file=docker-compose-production.yml down)

