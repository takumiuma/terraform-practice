# syntax=docker/dockerfile:1

# --- build stage ---
# ECS Fargate は x86_64 で動くため、ビルドマシンに関わらず amd64 に固定する。
# （Apple Silicon 等の arm64 マシンでも --platform 指定なしで正しい成果物になる）
FROM --platform=linux/amd64 golang:1.22-alpine AS build
WORKDIR /src

# 依存を先にキャッシュ
COPY go.mod go.sum ./
RUN go mod download

# ソースをコピーして静的バイナリをビルド（GOARCH も明示して amd64 を保証）
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server

# --- runtime stage ---
# distroless: シェルもパッケージマネージャも持たない最小イメージ（攻撃面・サイズ最小）
FROM --platform=linux/amd64 gcr.io/distroless/static-debian12:nonroot
WORKDIR /
COPY --from=build /out/server /server
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/server"]
