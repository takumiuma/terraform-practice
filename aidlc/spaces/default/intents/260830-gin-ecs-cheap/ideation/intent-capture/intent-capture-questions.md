# Intent Capture — Clarifying Questions

## Sources

- [desc] Initial description: "ginサーバーをECSで一番安く立てたい。terraformで実装してほしい。"
- [scope] Workflow-selected scope: `gin-ecs-cheapest-terraform`.

---

これから作るものの意図を確定するための質問です。すでにチャットで教えていただいた内容（月1000円以内、使い捨て前提の create/destroy 運用、Goの資材をデプロイして動作確認するレベル）は各質問の選択肢に反映済みです。確認・修正をお願いします。

各質問の `[Answer]:` に、選んだ選択肢（例: `A`）または自由記述を書いてください。`X. Other` を選ぶ場合は内容も添えてください。

## Q1. 解決したい課題は何ですか？

- A. ECS上でGin(Go)サーバーを最小コストで動かす方法を学ぶ・検証する（練習・学習目的）
- B. 本番運用するサービスの土台を作る
- C. 特定機能のPoC（概念実証）を素早く立てて捨てたい
- D. Not yet defined
- X. Other (please specify)

[Answer]: A

## Q2. 誰が使いますか（利用者）？

- A. 自分（開発者本人）だけ。動作確認・学習用途
- B. チーム内の開発者
- C. 外部のエンドユーザー
- D. Not identified
- X. Other (please specify)

[Answer]: A

## Q3. 「成功」の状態はどれですか（成功指標）？

- A. `terraform apply` でGinサーバーが立ち上がり、HTTPでアクセスして応答が返る。`terraform destroy` で綺麗に消える。月額コストが1000円以内に収まる
- B. 上記に加え、常時稼働で安定してリクエストを捌ける
- C. 上記に加え、複数環境（staging/prod）に展開できる
- D. Not yet defined
- X. Other (please specify)

[Answer]: A

## Q4. この取り組みのきっかけは何ですか？

- A. AWS/Terraform/ECSの学習・実験
- B. コスト最適化の検証
- C. 新機能・新サービスの立ち上げ
- D. Not applicable
- X. Other (please specify)

[Answer]: A

## Q5. 主要なステークホルダーは誰ですか？

- A. 自分ひとり（意思決定も実装も自分）
- B. 開発チーム＋レビュアー
- C. プロダクトオーナー等の承認者を含む
- D. Not identified
- X. Other (please specify)

[Answer]: A

## Q6. スコープ・優先度は誰が決めますか？

- A. 自分（単独判断）
- B. チームで合議
- C. 上位承認者
- D. Not applicable
- X. Other (please specify)

[Answer]: A

## Q7. 報告・コミュニケーションの要件はありますか？

- A. なし（個人の練習なので不要）
- B. チームへの共有が必要
- C. 定期報告が必要
- D. None
- X. Other (please specify)

[Answer]: A

## Q8. ワークフローは `gin-ecs-cheapest-terraform` スコープで開始しました。このスコープ（Gin server を ECS に最安構成で Terraform で立てる）は、あなたが意図するプロダクト境界と一致していますか？

- A. はい、一致している（Ginサーバー / ECS / 最安 / Terraform、使い捨て運用が前提）
- B. だいたい一致しているが、境界を少し変えたい（内容を記述）
- C. いいえ、別のプロダクト境界を定義したい（内容を記述）
- D. Not yet defined
- X. Other (please specify)

[Answer]: A（ただし、ビルド・デプロイは GitHub → GitHub Actions → ECR → ECS のパイプラインを前提とする。Terraform実装はこの構成を考慮すること — ECRリポジトリ、ECS関連リソース、GitHub Actions用のOIDC/IAMロールを含む）

## Q9. コスト最優先の方針について、以下の前提で進めてよいですか？（月1000円以内が目標）

- A. はい。使うときだけ `terraform apply`、終わったら `terraform destroy` の使い捨て運用。常時稼働は前提にしない
- B. 使い捨てでよいが、目標コストを変えたい（金額を記述）
- C. 常時稼働も視野に入れたい
- D. Not yet defined
- X. Other (please specify)

[Answer]: A

## Consolidated Summary Confirmation

以下の内容で意図を確定し、成果物（intent-statement / stakeholder-map）を生成します。よろしいですか？

**解決したい課題 / きっかけ (Q1, Q4):** AWS/Terraform/ECS の学習・実験として、Gin(Go)サーバーを ECS 上で最小コストで動かす方法を検証する。

**利用者 / ステークホルダー (Q2, Q5, Q6, Q7):** 開発者本人ひとり。意思決定・実装・スコープ判断もすべて本人。報告要件なし。

**成功指標 (Q3):** `terraform apply` で Gin サーバーが起動し HTTP で応答が返る → `terraform destroy` で綺麗に消える → 月額コストが1000円以内。

**プロダクト境界 (Q8):** Gin server を ECS に最安構成で Terraform で立てる。ビルド・デプロイは **GitHub → GitHub Actions → ECR → ECS** のパイプラインを前提とする。Terraform実装はこの構成を考慮する（ECRリポジトリ、ECS関連リソース、GitHub Actions用のOIDC/IAMロールを含む）。

**コスト方針 (Q9):** 使うときだけ create、終わったら destroy の使い捨て運用。常時稼働は前提としない。月1000円以内が目標。

- Looks correct
- Request changes

[Answer]: Looks correct

## Assumption Confirmation

intent-statement に以下の assumption（現段階で未確定・後続フェーズで詰める事項）があります。これらの扱いを選んでください。

1. `destroy` 後も残存し課金され得るリソース（ECRイメージ、Terraform state）の扱いは、後続の要件・設計フェーズで確定する。
2. 「一番安く」の具体的なコスト水準（Fargate Spot / 最小 vCPU・メモリ / NAT Gateway の要否 / リージョン選択など）は、NFR要件・インフラ設計フェーズで詰める。
3. GitHub リポジトリおよび Go アプリケーション（Ginサーバー）の実体・配置は、後続フェーズで確定する。

- A. Accept assumptions
- B. Convert to follow-up questions

[Answer]: A. Accept assumptions
