# x-heep-docker
This directory contains the dockerfile to build the docker container to run the CI pipeline and to be used as an all-in-one solution to make experiments with X-HEEP.

## Docker content

- Verilator 5.040 (for RTL simulation)
- Verible (SystemVerilog source formatting and static analysis)
- GCC RISC-V baremetal toolchain (for software build)
- Clang (alternative for software build)
- Embecosm CORE-V RISC-V baremetal toolchain (for software build with PULP extension support)

## Quick Start

To use the Docker container to build X-HEEP and run applications on it, follow these steps:

1. Pull the docker image from docker-hub:

    ```bash
    make docker-pull
    ```

2. Once that the image is pulled you can mount X-HEEP inside the container and open a shell in it:

    ```bash
    make docker-run
    ```

3. Follow X-HEEP [documentation](https://x-heep.readthedocs.io/en/latest/index.html) to generate the RTL of the SoC, build the simulation model, and run applications.

## Modify the Image (for the Maintainers)

For testing purposes, the container can be built locally. To upgrade the tools included in the Docker container, edit the [`dockerfile`](./dockerfile). Once you are happy with your changes, you can build the image with:

```bash
make docker-build
```

This target will first pull the latest version of the toolchain from the [X-HEEP GitHub Releases](https://github.com/x-heep/x-heep/releases), and then build the Docker image using that toolchain. If you want to experiment with a different toolchain, you need to update the [`dockerfile`](./dockerfile) accordingly.

### Publishing an Updated Image
There is no need to push the container manually. The container is automatically built and pushed to the [GHCR registry](https://ghcr.io/x-heep/x-heep/x-heep-toolchain:latest) by the [`create-release.yml`](/.github/workflows/create-release.yml) GitHub workflow. This must be launched manually from the [GitHub Actions tab](https://github.com/x-heep/x-heep/actions). Remember to specify the release tag when doing so.

### Apptainer Version

An Apptainer image (SIF format) can be automatically generated from the Docker layers using the following command:

```bash
apptainer build x-heep-toolchain.sif docker://ghcr.io/x-heep/x-heep/x-heep-toolchain:latest
```
