# Risk and Sequencing Rationale

## 採用したヒューリスティック

**Walking-skeleton-first（Cockburn）** を採用。スコアリングモデル（WSJF 等）は使わない。理由: 小規模・単独・学習用途で、Unit 数も少なく、経済的順位付けの精緻化より「パイプラインとインフラの接続を最小構成で早期に証明する」ことの価値が明確に高いため。

## Bolt 順序の根拠

1. **Bolt 1（walking skeleton）を最初に:** 最大の未知は「最安構成（ALBなし・NATなし・Fargate最小・OIDC）で、GitHub→Actions→ECR→ECS のパイプラインとインフラが実際に接続し、外部から `/healthz` に応答が返り、使い捨てサイクルが成立するか」。これを最小の `/healthz` だけで先に証明することで、以降の作り込みが安全になる。DB を含めないことで skeleton を軽く速く保つ。
2. **Bolt 2（RDS + CRUD）を次に:** DB は追加のコスト要因（RDS の起動時間・ストレージ）であり、最大のコストリスク。skeleton でパイプラインが確立した後に RDS を足し、実コストを測って月1000円以内を検証する。ここで超過が見込まれる場合は DynamoDB フォールバックを検討する（FR4.4）。

## トポロジ順序との関係

2.7 の依存 DAG は gin-app → terraform-infra → cicd-pipeline。本 Bolt 計画はこの DAG に反しない: Bolt 1 が3ユニットの skeleton 部分をまとめて縦に貫き、Bolt 2 が同ユニット群に DB 機能を足す。トポロジ順序からの逸脱はない（各 Bolt 内でユニット間の依存順に実装する）。

## リスク登録

| リスク | 対応 | いつ |
|--------|------|------|
| 月額コストが1000円を超える（特に RDS） | 使い捨て運用（apply→確認→destroy）、RDS最安構成、スナップショット残さない。Bolt2で実コスト確認、超過見込みなら DynamoDB フォールバック検討 | Bolt 2 |
| OIDC認証・ECSデプロイが通らない | Bolt 1 の skeleton で最小構成のパイプラインを先に疎通させて早期検出 | Bolt 1 |
| NATなし構成で ECR イメージ取得ができない | インフラ設計で経路（パブリック or VPCエンドポイント）を確定 | Bolt 1（設計時） |
