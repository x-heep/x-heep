ROOT_DIR 			:= $(shell git rev-parse --show-toplevel)
TAG 				?= $(shell git describe --tags --abbrev=0)
GITHUB_REPOSITORY 	:= ghcr.io/x-heep/x-heep
IMAGE_NAME 			:= x-heep-toolchain
IMAGE_ID 			:= $(GITHUB_REPOSITORY)/$(IMAGE_NAME)
PLATFORM			?= linux/amd64
RUNFLAGS			?= --rm

# User targets

# Try to download the image corresponding to the current revision, else default to 'latest'
.PHONY: docker-pull
docker-pull:
	docker pull --platform $(PLATFORM) $(IMAGE_ID):$(TAG) || docker pull --platform linux/amd64 $(IMAGE_ID):latest

# Spawn a Docker container and mount the X-HEEP directory in `/workspace/x-heep`
.PHONY: docker-run
docker-run:
	docker run --platform $(PLATFORM) -it $(RUNFLAGS) -v $(ROOT_DIR):/workspace/x-heep $(IMAGE_ID):$(TAG)

# Build the image locally
.PHONY: docker-build
docker-build: toolchain.tar.gz
	docker build --platform $(PLATFORM) -t $(IMAGE_ID):$(TAG) -f ./dockerfile $(ROOT_DIR) --build-arg RISCV_TOOLCHAIN_TAR_FILE=util/docker/$<
#	$(RM) $<

toolchain.tar.gz:
	wget $$(curl -s https://api.github.com/repos/x-heep/x-heep/releases/latest | grep -o 'https://[^"]*ubuntu2204.tar.gz' | head -n 1) -O $@
