.PHONY: image latest latest-tag test deploy-local local login-deploy

-include .env

branch ?= master
DOCKERFILE_BUILD=/tmp/Dockerfile.image
NAME_IMAGE ?= "$(CI_REGISTRY_IMAGE)"
TAG_IMAGE := branch-$(subst /,-,$(branch))-$(src)
PYTHON_FOLDER = "linux-app"

# We use :latest so we can use somewhere else, but it's the same as branch-master the other one is for CI
ifeq ($(branch), latest)
	TAG_IMAGE=latest
endif

IMAGE_URL_DEB = ubuntu:latest
IMAGE_URL_RPM = fedora:latest
IMAGE_URL_ARCH = archlinux:base-devel-20210131.0.14634

# Run make base to build both images based on ubuntu and fedora
base: image-deb image-rpm image-arch

# Create the image based on ubuntu
image-deb: image
image-deb: DOCKER_FILE_SOURCE = Dockerfile.deb
image-deb: src = ubuntu

# Create the image based on fedora
image-rpm: image
image-rpm: DOCKER_FILE_SOURCE = Dockerfile.rpm
image-rpm: src = fedora

# Create the image based on archlinux
image-arch: image
image-arch: DOCKER_FILE_SOURCE = Dockerfile.arch
image-arch: src = archlinux

## Make remote image form a branch make image branch=<branchName> (master default)
image: requirements.txt docker-source
	docker build -t $(NAME_IMAGE):$(TAG_IMAGE) -f "$(DOCKERFILE_BUILD)" \
	--network=host \
	--build-arg git_repo_lib=$(GIT_REPO_LIB) \
	--build-arg git_repo_client=$(GIT_REPO_CLIENT) \
	--build-arg git_branch=$(GIT_BRANCH) \
	.
	docker push $(NAME_IMAGE):$(TAG_IMAGE)
	docker tag $(NAME_IMAGE):$(TAG_IMAGE) $(NAME_IMAGE):$(TAG_IMAGE)

## We host our own copy of the image ubuntu:latest
docker-source:
	sed "s|IMAGE_URL_RPM|$(IMAGE_URL_RPM)|; s|IMAGE_URL_DEB|$(IMAGE_URL_DEB)|; s|IMAGE_URL_ARCH|$(IMAGE_URL_ARCH)|" $(DOCKER_FILE_SOURCE) > /tmp/Dockerfile.image

requirements.txt:
	@ touch requirements.txt

# Tag the image branch-master as latest
latest:
	docker pull $(NAME_IMAGE):branch-master-$(src)	
	docker tag $(NAME_IMAGE):branch-master-$(src)  $(NAME_IMAGE):latest-$(src)
	docker push $(NAME_IMAGE):latest-$(src)

## Build image on local -> name nm-core:latest
local: docker-source
		docker build -t $(NAME_IMAGE):$(TAG_IMAGE) -f "$(DOCKERFILE_BUILD)" \
	--network=host \
	--build-arg git_repo_lib=$(GIT_REPO_LIB) \
	--build-arg git_repo_client=$(GIT_REPO_CLIENT) \
	--build-arg git_branch=$(GIT_BRANCH) \
	.
	@ rm -rf __SOURCE_APP || true
local: NAME_IMAGE = $(PYTHON_FOLDER):latest

local-base: local-deb local-rpm local-arch

local-deb: local
local-deb: DOCKER_FILE_SOURCE = Dockerfile.deb

local-rpm: local
local-rpm: DOCKER_FILE_SOURCE = Dockerfile.rpm

local-arch: local
local-arch: DOCKER_FILE_SOURCE = Dockerfile.arch

# Build an image from your computer and push it to our repository
deploy-local: login-deploy build tag push

# If you want to deploy an image to our registry you will need to set these variables inside .env
login-deploy:
	docker login -u "$(CI_DEPLOY_USER)" -p "$(CI_JOB_TOKEN)" "$(CI_REGISTRY)"

######### Not linked to the image ###############

## Run tests against the latest version of the deb from your code
test-deb: local-deb
	# Keep -it because with colors it's better
	@ docker run \
			--rm \
			-it \
			--privileged \
			--volume $(PWD)/home/user/$(PYTHON_FOLDER)/ \
			$(PYTHON_FOLDER):latest \
			python3 -m pytest

## Run tests against the latest version of the rpm from your code
test-rpm: local-rpm
	# Keep -it because with colors it's better
	@ docker run \
			--rm \
			-it \
			--privileged \
			--volume $(PWD)/home/user/$(PYTHON_FOLDER)/ \
			$(PYTHON_FOLDER):latest \
			python3 -m pytest

## Run tests against the latest version of the arch from your code
test-arch: local-arch
	# Keep -it because with colors it's better
	@ docker run \
			--rm \
			-it \
			--privileged \
			--volume $(PWD)/home/user/$(PYTHON_FOLDER)/ \
			$(PYTHON_FOLDER):latest \
			python3 -m pytest
