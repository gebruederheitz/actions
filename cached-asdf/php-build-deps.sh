#!/usr/bin/env bash
# Installs the Debian/Ubuntu packages needed to compile PHP with asdf-php
# (php-build). Run by cached-asdf's "Install PHP build-time dependencies" step.
set -euo pipefail

# Debian/Ubuntu package list vendored from php-build's install-dependencies.sh
# (the `debian|ubuntu)` branch) at php-build/php-build@2fecc9da7425e66307fca0341267a239c4502d25,
# plus our own libgd-dev. See "Updating the PHP build dependencies" in the README.
packages=(
  autoconf
  bash
  bison
  build-essential
  ca-certificates
  curl
  findutils
  git
  libbz2-dev
  libcurl4-gnutls-dev
  libicu-dev
  libjpeg-dev
  libmcrypt-dev
  libonig-dev
  libpng-dev
  libreadline-dev
  libsqlite3-dev
  libssl-dev
  libtidy-dev
  libxml2-dev
  libxslt1-dev
  libzip-dev
  pkg-config
  re2c
  zlib1g-dev
  # Not in php-build's list, see the README.
  libgd-dev
)
# Bound network waits so an unreachable mirror fails the step within
# minutes instead of hanging. The retry and timeout values match what
# GitHub's Ubuntu images preset (stated here for runners without them);
# the hard ceilings are ~10x a healthy run (composite steps cannot set
# timeout-minutes).
apt_opts=(
  -o Acquire::Retries=1
  -o Acquire::http::Timeout=15
  -o Acquire::https::Timeout=15
)
sudo DEBIAN_FRONTEND=noninteractive timeout 2m apt-get "${apt_opts[@]}" -q update
sudo DEBIAN_FRONTEND=noninteractive timeout 5m apt-get "${apt_opts[@]}" -q -y \
  --no-install-recommends install "${packages[@]}"
