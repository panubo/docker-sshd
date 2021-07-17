NAME := sshd
USER := panubo

TAG := latest
IMAGE_NAME := $(USER)/$(NAME)

DOCKER := docker

ARCH_LIST := linux/amd64 linux/386 linux/arm64 linux/ppc64le linux/s390x linux/arm/v7 linux/arm/v6
comma := ,
COM_ARCH_LIST:= $(subst $() $(),$(comma),$(ARCH_LIST))

.PHONY: help build push clean

help:
	@printf "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\x1b[36m\1\\x1b[m:\2/' | column -c2 -t -s :)\n"

build: ## Builds docker image latest
	$(DOCKER) build --pull -t $(IMAGE_NAME):latest .

push: qemu ## Pushes the docker image to hub.docker.com
	# Don't --pull here, we don't want any last minute upsteam changes
	$(DOCKER) buildx build . -t $(IMAGE_NAME):$(TAG) -t $(IMAGE_NAME):latest \
	--platform $(COM_ARCH_LIST) --push

qemu:
	export DOCKER_CLI_EXPERIMENTAL=enabled
	$(DOCKER) run --rm --privileged multiarch/qemu-user-static --reset -p yes
	$(DOCKER) buildx create --name qemu_builder --driver docker-container --use || true
	$(DOCKER) buildx inspect --bootstrap

clean: ## Remove built images
	$(DOCKER) rmi $(IMAGE_NAME):latest || true
	$(DOCKER) rmi $(IMAGE_NAME):$(TAG) || true
