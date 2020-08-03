image := gcr.io/bowei-gke/debug-vm
version ?= $(shell git describe --tags --always --dirty)

all:
	docker build . -t $(image):$(version) -f Dockerfile
	docker build . -t $(image) -f Dockerfile
	docker push $(image):$(version)
	docker push $(image)
	# ftrace
	docker build . -t $(image)-ftrace:$(version) -f Dockerfile.ftrace
	docker build . -t $(image)-ftrace -f Dockerfile.ftrace
	docker push $(image)-ftrace:$(version)
	docker push $(image)-ftrace