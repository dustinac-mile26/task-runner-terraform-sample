PROJECT := myorganization

PWD=$(shell pwd)
export MAKE_PATH ?= $(abspath $(firstword $(MAKEFILE_LIST)))
export ROOT_PATH ?= $(dir $(MAKE_PATH))

ifeq ($(DEPLOY_ENV),)
  $(error "DEPLOY_ENV not set")
endif

SHELL := bash

COLOR_YELLOW := \e[1;33m
COLOR_NC := \e[0m

ifndef DEPLOY_ENV
  DEPLOY_ENV := development
endif

BUILD_DIRECTORY := /tmp/$(PROJECT).$(DEPLOY_ENV).build

.PHONY: default
default: help

# internal recipes

clean:
	@rm -rf $(BUILD_DIRECTORY)

temp-create:
	$(eval export TEMP_ROOT := $(shell umask 077 && mktemp -d /tmp/$(PROJECT).$(DEPLOY_ENV).XXXXXXXX))
	@echo "Using temp directory: $(TEMP_ROOT)"

temp-delete: ## delete temp directory
	rm -rfv $(TEMP_ROOT)# git targets

check:
	@if [ ! -z $(FORCE) ]; then echo "Forcing..."; exit 0; fi; \
		echo "Are you sure? [NO/yes]:"; \
		read answer; \
		if [ "$$answer" != "yes" ]; then echo "Must answer 'yes' to proceed."; exit 1; fi

env-check:
	@echo "Using DEPLOY_ENV: $(DEPLOY_ENV)." ;\
		echo "Sleeping 2s before continuing... Control-C now to abort!" ;\
		sleep 2; \

# from https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## print this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort \
		| sed 's/^.*\/\(.*\)/\1/' \
		| awk 'BEGIN {FS = ":( ##)?"}; {printf "\033[36m%-32s\033[0m %-60s (%s)\n", $$2, $$3, $$1}' \
		| sort

# include additional targets
include $(shell find -L . -mindepth 1 -maxdepth 5 -name '*.mk' -not -path "./build/*")