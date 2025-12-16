# syntax=docker/dockerfile:1.4

FROM ruby:3.4.7-slim-trixie AS ruby

WORKDIR /app
SHELL ["/bin/bash", "-c"]
CMD ["/bin/bash"]

RUN \
  --mount=type=cache,id=fresh-apt-cache,sharing=locked,target=/var/cache/apt \
  --mount=type=cache,id=fresh-apt-lib,sharing=locked,target=/var/lib/apt \
  <<SH
  set -euo pipefail
  rm /etc/apt/apt.conf.d/docker-clean
  echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
  apt-get update --yes
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    perl git
SH

COPY .tool-versions ./

RUN <<SH
  set -e
  ruby --version
  (
    echo "ruby ${RUBY_VERSION?}"
  ) | diff - .tool-versions
SH

COPY Gemfile* ./

RUN \
  --mount=type=cache,id=fresh-bundle-cache,target=/var/cache/bundle \
  <<SH
  set -euo pipefail
  BUNDLE_CACHE_PATH="/var/cache/bundle/debian-$(cat /etc/debian_version)-ruby-$RUBY_VERSION"
  GEM_HOME="$BUNDLE_CACHE_PATH" gem install --conservative bundler:$(tail -n1 Gemfile.lock | awk '{print $1}')
  GEM_HOME="$BUNDLE_CACHE_PATH" bundle install --no-clean
  echo "Copying bundle cache to target..."
  tar c -C "$BUNDLE_CACHE_PATH" --anchored --no-wildcards-match-slash --exclude=./cache . | tar x -C /usr/local/bundle
  bundle clean --force
SH

COPY . ./

RUN <<EOF
  mkdir /app/tmp
  chmod 1777 /tmp /app/tmp
  useradd -m user
EOF

USER user
