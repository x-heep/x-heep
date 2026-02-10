# Automatic testing

X-HEEP includes a script to perform automatic tests on your modifications. In addition, it also has a CI setup that checks the code by simulating all the existing applications and handles publishing new X-HEEP releases.

## Simulation script

The testing script (`test/test_apps/test_apps.py`) can be used to perform local tests. For quick
debugging, you can check the global variables in the script such as the `BLACKLIST` and `WHITELIST`.

You can run it with the following command:

```bash
make test
```

This will output the results in the terminal and in the `test/test_apps/test_apps.log` file.

Additionally, you can check only the compilation of the applications with the following command:

```bash
make test TEST_FLAGS=--compile-only
```

This script is also integrated in the CI workflow described in the following section.

## Github CIs

The project's Continuous Integration (CI) is managed through GitHub Actions. The workflows are defined in the `.github/workflows` directory. The main CI workflow is `ci.yml`, which is triggered on every push and pull request to the `main` branch.

### CI Workflow (`ci.yml`)

This workflow ensures the stability and integrity of the codebase by running a series of checks, compilations, and simulations.

**Triggers:**

*   Push to any branch (`push: branches: [ "**" ]`).
*   Pull request to the `main` branch (`pull_request: branches: [ "main" ]`).

**Jobs:**

1.  **`determine-image-tag`**:
    *   **Purpose**: Determines the Docker image tag to be used by subsequent jobs.
    *   **Details**: It checks the Git history for the most recent tag. If no tag is found in the current branch, it looks for one in the `main` branch. If no tags are found at all, it defaults to `latest`. This ensures that the CI always uses a relevant toolchain version.

2.  **`compile-apps`**:
    *   **Purpose**: Compiles all software applications with both GCC and Clang to ensure they build correctly.
    *   **Dependencies**: Depends on `determine-image-tag` to select the correct Docker image.
    *   **Environment**: Runs inside the `ghcr.io/x-heep/x-heep/x-heep-toolchain` Docker container.
    *   **Steps**:
        *   Generates the MCU configuration using `make mcu-gen X_HEEP_CFG=configs/ci.hjson`.
        *   Executes `test/test_apps/test_apps.py` with the `--compile-only` flag to build all applications, without simulating them. This is done to offer a quick feedback about the apps' integrity, before their runtime behaviour is checked in RTL simulation.

3.  **`simulate-apps`**:
    *   **Purpose**: Runs Verilator RTL simulations for all applications (except the blacklisted ones) to verify their runtime behavior.
    *   **Condition**: This job only runs on pull requests to `main`.
    *   **Dependencies**: Depends on `determine-image-tag`.
    *   **Environment**: Runs inside the `x-heep-toolchain` Docker container.
    *   **Steps**:
        *   Generates the MCU configuration using `make mcu-gen X_HEEP_CFG=configs/ci.hjson`.
        *   Executes `test/test_apps/test_apps.py` to compile and simulate all applications.

4.  **`lint`**:
    *   **Purpose**: Checks that all auto-generated hardware files are up-to-date and have been formatted .
    *   **Dependencies**: Depends on `determine-image-tag`.
    *   **Environment**: Runs inside the `x-heep-toolchain` Docker container.
    *   **Steps**:
        *   Runs `make mcu-gen` to regenerate all hardware files.
        *   Uses `util/git-diff.py` to check for any differences between the working directory and the git HEAD. The job fails if any differences are found.

5.  **`gen-peripherals`**:
    *   **Purpose**: Tests the Python-based peripheral generation scripts and templates.
    *   **Dependencies**: Depends on `determine-image-tag`.
    *   **Environment**: Runs inside the `x-heep-toolchain` Docker container.
    *   **Steps**:
        *   Runs `make clean-all` to ensure a clean state.
        *   Executes `test/test_x_heep_gen/test_peripherals.py`.

6.  **`check-vendor`**:
    *   **Purpose**: Verifies that all third-party vendored dependencies are up-to-date.
    *   **Environment**: Runs inside a `ubuntu-latest` VM.
    *   **Steps**:
        *   Installs Python dependencies.
        *   Runs the `util/vendor.py` script for all `.vendor.hjson` files to re-vendor all dependencies.
        *   Uses `util/git-diff.py` to check for any differences, ensuring that any changes to vendored repositories are properly committed.

7.  **`black-formatter`**:
    *   **Purpose**: Checks that all Python code adheres to the `black` formatting standard.
    *   **Environment**: Runs inside a `ubuntu-latest` VM.
    *   **Steps**:
        *   Uses the `psf/black` GitHub Action to check the formatting of all relevant Python files.

### Release Workflows

The project includes a robust, automated process for creating and publishing releases. This is handled by two GitHub Actions workflows: `create-release.yml` and `publish-release.yml`. This system ensures that every release is consistently built, tested, and published with its corresponding toolchain and Docker image.

#### Create X-HEEP Release Workflow (`create-release.yml`)

This workflow prepares a new release. It is a comprehensive process that builds the toolchain, packages it, creates a draft release, builds a Docker container, and opens a version bump pull request. It's designed to be triggered manually when a new release is needed.

**Trigger:**

*   Manual dispatch (`workflow_dispatch`) from the GitHub Actions tab.
*   **Inputs**:
    *   `llvm_version`: The LLVM version tag to build (default: `llvmorg-19.1.4`).
    *   `gcc_version`: The GCC version tag to build (default: `2023.01.03`).
    *   `release_tag`: The tag for the new GitHub release (e.g., `v1.0.0`).

```{note}
This workflow is intended for major releases that:
- Introduce support for new tools
- Bump existing tools to newer versions
- Modify the CI workflows
- Represent a significant update in general

Minor bug fixes or feature improvements may not require/justify a full new release.
```

**Jobs:**

1.  **`check-changes`**:
    *   Checks previous release tag.
    *   Downloads `tool-versions.env` from the previous release to compare GCC, LLVM, Verilator, and Verible versions.
    *   Checks for changes in Docker-related files (`util/docker/`, `util/conda_environment.yml`, `util/python-requirements.txt`, `docs/python-requirements.txt`).
    *   Sets outputs `rebuild_toolchain` and `rebuild_docker` to avoid unnecessary rebuilds.

2.  **`prepare-release`**:
    *   Creates a new release branch (`release/<release_tag>`).
    *   Updates the version in `core-v-mini-mcu.core` and the toolchain version in `util/docker/dockerfile`.
    *   Commits and pushes the changes to the new branch.
    *   Creates a **draft** GitHub release.

3.  **`build-and-upload-toolchain`**:
    *   **Conditional**: Runs the build only if `rebuild_toolchain` is true.
    *   Builds the RISC-V GCC and Clang/LLVM toolchains from the sources specified in the workflow inputs.
    *   Packages the compiled toolchains into a `.tar.gz` file.
    *   If `rebuild_toolchain` is false, it downloads the toolchain asset from the previous release.
    *   Uploads the toolchain tarball as an asset to the draft GitHub release.
    *   Uploads a `tool-versions.env` file containing version metadata.

4.  **`build-docker`**:
    *   **Conditional**: Runs the build only if `rebuild_docker` is true.
    *   Downloads the toolchain asset from the draft release.
    *   Builds the `x-heep-toolchain` Docker image, injecting the new toolchain.
    *   Pushes the new Docker image to the GitHub Container Registry (GHCR) with the release tag.
    *   If `rebuild_docker` is false, it retags the previous release's Docker image with the new tag.

5.  **`create-version-pr`**:
    *   Creates a new pull request to merge the release branch back into `main`. This PR contains the version bumps.

6.  **`cleanup-on-failure`**:
    *   This job runs only if any of the previous jobs fail.
    *   It automatically cleans up by deleting the draft release, the release tag, the remote release branch, and the pushed Docker image from GHCR. This prevents leftovers from partial, broken releases.

#### Publish Release Workflow (`publish-release.yml`)

This workflow finalizes the release process. It is triggered automatically after the version bump PR (created by the `create-release.yml` workflow) is merged into the `main` branch.

**Trigger:**

*   A pull request from a `release/*` branch is merged into `main`.

**Jobs:**

1.  **`publish-release`**:
    *   Identifies the release tag from the merged branch name.
    *   Converts the corresponding draft release into a **public release**.
    *   Deletes the now-merged remote release branch to keep the repository clean.

2.  **`tag-latest`**:
    *   After the release is published, this job pulls the newly released Docker image from GHCR.
    *   It then re-tags this image with the `latest` tag and pushes it.
    *   This ensures that the main `ci.yml` workflow will use the most up-to-date toolchain for future runs on the `main` branch.

## Compare mcu-gen runs

The `test/test_x_heep_gen/compare_mcu_gen.py` script is a utility to compare the outputs of mcu-gen between the current branch and main. This can be useful to manually check if changes in the configuration or in the MCU-Gen code have an effect on the generated files.

You can run it with the following command:

```bash
make compare-mcu-gen
```

This will generate the mcu-gen outputs in the `_mcu_gen_current` and `_mcu_gen_main` directories inside `test/test_x_heep_gen`, and then list the files that differ between them. You can check the differences to see if they are expected or if they indicate an unintended change in the generated files.
