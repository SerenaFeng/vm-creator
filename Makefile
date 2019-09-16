# It's necessary to set this because some environments don't link sh -> bash.
SHELL := /bin/bash

# Constants used throughout.
# We don't need make's built-in rules.
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

.EXPORT_ALL_VARIABLES:
HELP := =y print this help information
d ?= False
p ?= pod1 # lowercase p, pod name
P ?= vms # uppercase P, prefix for node name
l ?= vms

define INSTALL_HELP
# Deploy k8s locally or on vms.
#
# Args:
#   h: $(HELP)
#   p: pod name, definded under config/labs, default by pod1
#   P: prefix for node name, default by cactus
#   l: cleanup level, dib=all resources, sto=all except dib image, vms=only vms and networks, default by vms
# Example:
#   make install p=pod1 P=serena l=vms
#   
endef
.phone: install
ifeq ($(h), y)
install:
	@echo "$$INSTALL_HELP"
else
install:
	sudo CI_DEBUG=$(d) bash deploy/deploy.sh -p $(p) -P $(P) -l $(l)
endif

define STOP_HELP
# STOP deployment.
#
# Args:
#   h: $(HELP)
# Example:
#   make stop
#
endef
.phone: stop
ifeq ($(h), y)
stop:
	@echo "$$STOP_HELP"
else
stop: 
	bash ./deploy/stop.sh
endif

define CLEAN_HELP
# Clean deployment envs.
#
# Args:
#   h: $(HELP)
#   p: pod name, definded under config, default by pod1
#   l: cleanup level, dib=all resources, sto=all except dib image, vms=only vms and networks, default by vms
#   P: uppercase, prefix for node name, default by cactus
# Example:
#   make clean P=cactus c=dib
#
endef
.phone: clean
ifeq ($(h), y)
clean:
	@echo "$$CLEAN_HELP"
else
clean:
	sudo CI_DEBUG=$(debug) bash deploy/clean.sh -P $(P) -l $(l) -p $(p)
endif

define VM_BUILD_HELP
# Build vm image
#
# Args:
#   h: $(HELP)
#   image: image name, for example ubuntu/ubuntu16.04.qcow2
#   dib: diskimage-builder defined elements
#   pkg: dpkg packages
#   v: output directory on host
# Example:
#   make vm_build dib=common-static pkg=curl image=ubuntu/ubuntu16.04.qcow2
endef
.phone: vm_build
ifeq ($(h), y)
vm_build:
	@echo "$$VM_BUILD_HELP"
else
vm_build:
	docker run --privileged -tid --rm --name dib -v $(v):/home/out --env DIB_OPTS=$(dib) --env PKG_OPTS=$(pkg) serenafeng/dib /home/create_image.sh $(image)
endif

.phone: docker_build
docker_build:
	cd docker; docker build -t serenafeng/dib:latest .
