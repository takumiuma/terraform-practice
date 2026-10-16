package handler

import (
	"fmt"
	"os"

	"github.com/glebarez/sqlite"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

// OpenDB は環境変数から DB 接続情報を組み立てて GORM で接続し、
// Item スキーマを AutoMigrate する。
//
// DB_DRIVER=sqlite の場合（Lambda + EFS 構成）は DB_PATH（既定 /mnt/data/app.db）の
// SQLite ファイルを開く。それ以外は MySQL（ECS + RDS 構成）として扱う。
//
// MySQL の必要な環境変数: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME
// 秘密はコードに埋め込まず環境変数（実体は SSM Parameter Store）から受け取る。
// いずれかが未設定の場合は接続を試みず (nil, nil) を返し、呼び出し側が
// DB 非依存の walking skeleton 構成として起動できるようにする。
func OpenDB() (*gorm.DB, error) {
	if os.Getenv("DB_DRIVER") == "sqlite" {
		return OpenSQLite(getenvDefault("DB_PATH", "/mnt/data/app.db"))
	}
	return openMySQL()
}

// OpenSQLite は path の SQLite を開いて AutoMigrate する。
//
// EFS（NFS）上で使う前提のため:
//   - journal_mode は既定の DELETE のまま（WAL は共有メモリを使うため NFS では使わない）
//   - busy_timeout=5000 でロック待ちを 5 秒まで許容する
//   - 接続は 1 本に絞り、同一プロセス内での同時書き込みを起こさない
func OpenSQLite(path string) (*gorm.DB, error) {
	dsn := path + "?_pragma=busy_timeout(5000)"
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, fmt.Errorf("failed to open sqlite database: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("failed to get sqlite connection pool: %w", err)
	}
	sqlDB.SetMaxOpenConns(1)

	if err := db.AutoMigrate(&Item{}); err != nil {
		return nil, fmt.Errorf("failed to auto-migrate schema: %w", err)
	}

	return db, nil
}

func openMySQL() (*gorm.DB, error) {
	host := os.Getenv("DB_HOST")
	user := os.Getenv("DB_USER")
	pass := os.Getenv("DB_PASSWORD")
	name := os.Getenv("DB_NAME")
	if host == "" || user == "" || pass == "" || name == "" {
		// いずれか未設定なら skeleton モード（/healthz のみ）。
		return nil, nil
	}
	port := getenvDefault("DB_PORT", "3306")

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
