FROM --platform=$BUILDPLATFORM tonistiigi/xx:1.2.1@sha256:8879a398dedf0aadaacfbd332b29ff2f84bc39ae6d4e9c0a1109db27ac5ba012 AS xx

FROM --platform=$BUILDPLATFORM golang:1.21.3-alpine3.18@sha256:926f7f7e1ab8509b4e91d5ec6d5916ebb45155b0c8920291ba9f361d65385806 AS builder

COPY --from=xx / /

RUN apk add --update --no-cache ca-certificates make git curl clang lld

ARG TARGETPLATFORM

RUN xx-apk --update --no-cache add musl-dev gcc

RUN xx-go --wrap

WORKDIR /usr/local/src/openmeter

ARG GOPROXY

ENV CGO_ENABLED=1

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG VERSION

# See https://github.com/confluentinc/confluent-kafka-go#librdkafka
# See https://github.com/confluentinc/confluent-kafka-go#static-builds-on-linux
# Build server binary (default)
RUN go build -ldflags "-linkmode external -extldflags \"-static\" -X main.version=${VERSION}" -tags musl -o /usr/local/bin/openmeter ./cmd/server
RUN xx-verify /usr/local/bin/openmeter

# Build sink-worker binary
RUN go build -ldflags "-linkmode external -extldflags \"-static\" -X main.version=${VERSION}" -tags musl -o /usr/local/bin/openmeter-sink-worker ./cmd/sink-worker
RUN xx-verify /usr/local/bin/openmeter-sink-worker

FROM gcr.io/distroless/base-debian11:latest@sha256:b31a6e02605827e77b7ebb82a0ac9669ec51091edd62c2c076175e05556f4ab9 AS distroless

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=builder /usr/local/bin/openmeter /usr/local/bin/
COPY --from=builder /usr/local/bin/openmeter-sink-worker /usr/local/bin/
COPY --from=builder /usr/local/src/openmeter/go.* /usr/local/src/openmeter/

CMD openmeter

FROM redhat/ubi8-micro:8.8-7@sha256:6fa456671239c7ac791dac2537425d1ba5612df36355deb0269824b6863b88ef AS ubi8

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=builder /usr/local/bin/openmeter /usr/local/bin/
COPY --from=builder /usr/local/bin/openmeter-sink-worker /usr/local/bin/
COPY --from=builder /usr/local/src/openmeter/go.* /usr/local/src/openmeter/

CMD openmeter

FROM alpine:3.18.4@sha256:eece025e432126ce23f223450a0326fbebde39cdf496a85d8c016293fc851978 AS alpine

RUN apk add --update --no-cache ca-certificates tzdata bash

SHELL ["/bin/bash", "-c"]

COPY --from=builder /usr/local/bin/openmeter /usr/local/bin/
COPY --from=builder /usr/local/bin/openmeter-sink-worker /usr/local/bin/
COPY --from=builder /usr/local/src/openmeter/go.* /usr/local/src/openmeter/

CMD openmeter
