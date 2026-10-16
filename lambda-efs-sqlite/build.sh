#!/usr/bin/env bash
# Lambda 用の Go バイナリ（bootstrap）を app/ からビルドする。
# provided.al2023 / arm64 向けの静的バイナリ。Terraform（初回）と CD（deploy-lambda.yml）の両方で使う。
set -euo pipefail

cd "$(dirname "$0")"
OUT_DIR="$(pwd)/build"
mkdir -p "$OUT_DIR"

(
  cd ../app
  GOOS=linux GOARCH=arm64 CGO_ENABLED=0 \
    go build -tags lambda.norpc -trimpath -ldflags="-s -w" -o "$OUT_DIR/bootstrap" ./cmd/lambda
)

echo "built: $OUT_DIR/bootstrap"
