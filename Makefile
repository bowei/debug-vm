image := gcr.io/bowei-gke/debug-vm

all:
	docker build . -t $(image)
	docker push $(image)
