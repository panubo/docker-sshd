NAME := sshd
TAG := latest
IMAGE_NAME := panubo/$(NAME)

.PHONY: *

help:
	@printf "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\x1b[36m\1\\x1b[m:\2/' | column -c2 -t -s :)\n"

build: ## Builds docker image latest
	docker build --pull -t $(IMAGE_NAME):latest .

push: ## Pushes the docker image to hub.docker.com
	# Don't --pull here, we don't want any last minute upsteam changes
	docker build -t $(IMAGE_NAME):$(TAG) .
	docker tag $(IMAGE_NAME):$(TAG) $(IMAGE_NAME):latest
	docker push $(IMAGE_NAME):$(TAG)
	docker push $(IMAGE_NAME):latest

clean: ## Remove built images
	docker rmi $(IMAGE_NAME):$(TAG) || true
	docker rmi $(IMAGE_NAME):$(TAG)-dev || true

test: clean ## Build a test image and run bats tests in docker
	docker build --target development -t $(IMAGE_NAME):$(TAG)-dev .
	docker run --rm -v $(shell pwd):/src -w /src $(IMAGE_NAME):$(TAG)-dev bats test/

_ci_test: test
	true
