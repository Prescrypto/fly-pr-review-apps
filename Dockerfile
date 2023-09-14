ARG ELIXIR_VERSION=1.15.4
ARG OTP_VERSION=26.0.2
ARG ALPINE_VERSION=3.18.2
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-3.18.2"

FROM ${BUILDER_IMAGE} as builder

RUN apk add --no-cache curl jq dasel

RUN curl -L https://fly.io/install.sh | FLYCTL_INSTALL=/usr/local sh

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
