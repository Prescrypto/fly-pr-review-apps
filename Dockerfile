ARG ELIXIR_VERSION=1.16.2
ARG OTP_VERSION=26.2.2
ARG ALPINE_VERSION=3.19.1
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"

FROM ${BUILDER_IMAGE} as builder

RUN apk add --no-cache curl jq dasel

RUN curl -L https://fly.io/install.sh | FLYCTL_INSTALL=/usr/local sh

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
