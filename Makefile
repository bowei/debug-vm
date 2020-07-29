image := gcr.io/bowei-gke/debug-vm
version ?= $(shell git describe --tags --always --dirty)

all:
	docker build . -t $(image):$(version)
	docker push $(image):$(version)
