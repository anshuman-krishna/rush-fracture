# the sqlite driver (mattn/go-sqlite3) needs cgo + a C toolchain to build —
# most Go base images default CGO_ENABLED=0, which fails or silently produces
# a broken binary. this Dockerfile sets it explicitly and builds on a glibc
# base so the runtime stage (also glibc) can run the resulting binary.
FROM golang:1.26-bookworm AS builder
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
ENV CGO_ENABLED=1
RUN go build -o /out/rush-fracture-backend ./cmd

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /out/rush-fracture-backend .

# override at runtime (docker run -e / compose environment:) — see
# internal/config/config.go for the full list and defaults.
ENV SERVER_ADDRESS=:8080
ENV DATABASE_PATH=/data/rush-fracture.db
VOLUME ["/data"]

EXPOSE 8080
ENTRYPOINT ["./rush-fracture-backend"]
