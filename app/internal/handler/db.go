package handler

import (
	"fmt"
	"os"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

// OpenDB は環境変数から MySQL 接続情報を組み立てて GORM で接続し、
// Item スキーマを AutoMigrate する。秘密はコードに埋め込まず環境変数
// （実体は SSM Parameter Store）から受け取る。
//
// 必要な環境変数: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME
// いずれかが未設定の場合は接続を試みず (nil, nil) を返し、呼び出し側が
// DB 非依存の walking skeleton 構成として起動できるようにする。
func OpenDB() (*gorm.DB, error) {
	host := os.Getenv("DB_HOST")
	if host == "" {
		// DB 未設定なら skeleton モード（/healthz のみ）。
		return nil, nil
	}
	port := getenvDefault("DB_PORT", "3306")
	user := os.Getenv("DB_USER")
	pass := os.Getenv("DB_PASSWORD")
	name := os.Getenv("DB_NAME")

	dsn := fmt.Sprintf(
		"%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		user, pass, host, port, name,
	)

	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		// 接続文字列（秘密を含む）はログにもエラーにも出さない。
		return nil, fmt.Errorf("failed to open database connection: %w", err)
	}

	if err := db.AutoMigrate(&Item{}); err != nil {
		return nil, fmt.Errorf("failed to auto-migrate schema: %w", err)
	}

	return db, nil
}

func getenvDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
