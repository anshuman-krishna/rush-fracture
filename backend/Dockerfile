# the sqlite driver (mattn/go-sqlite3) needs cgo and a C toolchain to build.
# most Go base images default to CGO_ENABLED=0, which fails or silently
# produces a broken binary. this Dockerfile sets it explicitly and builds on
# a glibc base so the runtime stage (also glibc) can run the result.
FROM golang:1.26-bookworm AS builder
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
ENV CGO_ENABLED=1
RUN go build -trimpath -ldflags="-s -w" -o /out/rush-fracture-backend ./cmd

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates wget \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --no-create-home app \
    && mkdir -p /data && chown app:app /data

WORKDIR /app
COPY --from=builder /out/rush-fracture-backend .

# override at runtime (docker run -e, or compose environment:). see
# internal/config/config.go for the full list and defaults.
ENV SERVER_ADDRESS=:8080
ENV DATABASE_PATH=/data/rush-fracture.db
VOLUME ["/data"]

# the service only needs to listen on a high port and write its database
USER app

EXPOSE 8080
ENTRYPOINT ["./rush-fracture-backend"]
