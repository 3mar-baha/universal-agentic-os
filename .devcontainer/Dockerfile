# Devcontainer image for the Universal Agentic Engineering OS.
#
# Tailored base: everything `uos doctor` checks for, preinstalled, so a
# fresh container passes doctor on first boot and only the 6-toolkit
# provisioning remains (handled by postCreateCommand).
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Lint and JSON tooling for the OS's own quality gates.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        shellcheck \
        jq \
        file \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
