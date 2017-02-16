SHELL := /bin/bash
SERVICE_NAME ?= smctest
AWS_REGION := eu-west-2
GIT_HASH := $(shell git rev-parse HEAD)
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
DOCKER_LOGIN ?= $(shell aws --region $(AWS_REGION) ecr get-login)

.PHONY: ecr-uri
ecr-uri:
	@aws --region $(AWS_REGION) \
		ecr describe-repositories \
		--output text \
		--repository-names $(SERVICE_NAME) \
		--query 'repositories[0].repositoryUri'

.PHONY: ecr-login
ecr-login:
	eval $$(aws --region $(AWS_REGION) ecr get-login)

.PHONY: ecs-createtask
ecs-createtask:
	sed "s^%DOCKER_IMAGE%^${DOCKER_IMAGE}^g" task.json.tmpl > task.json
	aws --region $(AWS_REGION) \
		ecs register-task-definition \
		--cli-input-json file://task.json

.PHONY: ecs-getrevision
ecs-getrevision:
	@aws --region $(AWS_REGION) \
		ecs describe-task-definition \
		--task-definition $(SERVICE_NAME) \
		--query 'taskDefinition.revision'

.PHONY: ecs-updateservice
ecs-updateservice:
	aws --region $(AWS_REGION) \
		ecs update-service \
		--cluster ${TARGET_ENV}-ecs \
		--service $(SERVICE_NAME) \
		--task-definition $(SERVICE_NAME):${TASKREV} \
		--desired-count 1

.PHONY: docker-build
docker-build:
	sed "s^%PLACEHOLDER%^$$(date)^g" testPage.scala.html > app/views/testPage.scala.html
	docker run -it --rm -v ${PWD}:/app -v "${HOME}/.ivy2":/root/.ivy2 1science/sbt sbt docker:stage
	cd target/docker/stage && docker build -t $(SERVICE_NAME) .

.PHONY: docker-push
docker-push: DOCKER_REPO = $(shell make ecr-uri)
docker-push:
	docker tag $(SERVICE_NAME):latest $(DOCKER_REPO):${DOCKER_TAG} && \
	docker push $(DOCKER_REPO):${DOCKER_TAG}


