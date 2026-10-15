# Security Requirements — gin-app

## Sources

- [requirements] requirements.md（NFR3、FR1.4、FR4.3）
- [memory] project.md ## Mandated / ## Forbidden（affirmed practices）

## 要件

| ID | 要件 | 内容 |
|----|------|------|
| NFR3.1 | 秘密情報の非ハードコード | DB接続情報などの秘密はコード/イメージ/tfvars に埋め込まず、環境変数（実体は SSM Parameter Store）経由で受け取る [FR4.3] |
| NFR3.2 | 内部情報の非漏洩 | `gin.SetMode(gin.ReleaseMode)` を用い、エラーレスポンスにスタックトレース等の内部情報を含めない [FR1.4] |
| NFR3.3 | 入力バリデーション | システム境界（HTTPハンドラ）で入力を検証・サニタイズする |
| NFR3.4 | ログの秘密非出力 | ログにトークン・認証情報・DB接続文字列を出力しない |
| NFR3.5 | 認証・認可 | 学習用途のためアプリ層の認証・認可は実装しない（out of scope）。外部公開は最小構成のパブリックIP直アクセスに限る |

## 脅威に関する考慮

- アプリは学習・使い捨て前提でパブリックIPに晒されるため、機微データを保持しない設計とする。DBには学習用のダミーデータのみを置く。
- 本格的な認証・WAF・DDoS対策はスコープ外（コスト最優先・使い捨て）。

## Assumptions & Open Questions

None.

<!-- Confirmed by human (summary-confirmation: Looks correct). -->

## Review

**Verdict:** READY
**Reviewer:** aidlc-architecture-reviewer-agent
**Date:** 2026-08-31T14:58:01Z
**Iteration:** 1

### Findings

| ID | Severity | Location | Finding | Required action | Status |
|---|---|---|---|---|---|
| R-01 | Minor | aidlc/spaces/default/intents/260830-gin-ecs-cheap/construction/gin-app/nfr-requirements/security-requirements.md > 要件 NFR3.5 | NFR3.5 後段「外部公開は最小構成のパブリックIP直アクセスに限る」はネットワーク公開・SG 設定の話で、unit-of-work.md 上は U2 (terraform-infra) の責務（VPC/パブリックサブネット/SG）。gin-app（アプリ service ユニット）の要件表に置くと、SG 開放範囲・RDS 非公開の実装責務がどのユニットにあるか読み手に曖昧。記述自体は誤りではなく「アプリ層に認証を持たない」判断の背景として妥当なため阻害しない。 | 任意。NFR3.5 は「アプリ層の認証・認可は out of scope」に絞り、ネットワーク公開面は U2 の責務である旨を一語添える。 | New |
| R-02 | Minor | aidlc/spaces/default/intents/260830-gin-ecs-cheap/construction/gin-app/nfr-requirements/security-requirements.md > 要件 NFR3.3 | NFR3.3 は境界での入力検証・サニタイズを要求するが、FR1.2 の MySQL CRUD について SQL インジェクション観点の具体（GORM のパラメータ化クエリ利用・raw SQL 連結の回避）が明文化されていない。GORM 既定はパラメータ化されるため学習用途では right-sized だが、実装者が raw query を書く余地は残る。 | 任意。NFR3.3 に「DB アクセスは GORM のパラメータ化経由とし、文字列連結の raw SQL を避ける」を一行補足すると実装ガードが明確になる。 | New |

### Validation Tool Results

| Tool | Result | Interpretation |
|---|---|---|
| traceability（手動検証） | PASS | traceability.json の NFR3=OK / target `NFR3.1..NFR3.5` は本ファイルの要件行と一致。上流 NFR3 の3つの affirmed 主張のうち OIDC(長期キー禁止)・ECR scan-on-push は unit-of-work.md 上 U2/U3 の責務で、gin-app の SSM 受け取り側要件(NFR3.1)・ログ非出力(NFR3.4)へ正しく写像。越境なし。 |
| cross-artifact 整合（手動検証） | PASS | NFR3.4 は observability NFR4.1 が `[NFR3.4]` で参照、NFR3.1 は tech-stack「環境変数(SSM実体)」が参照、NFR3.2 は FR1.4/performance の ReleaseMode と一致。sibling NFR 群と矛盾なし。 |

### Summary

gin-app のセキュリティ NFR は、ソロ学習・使い捨て・パブリックIP直アクセスでダミーデータのみという前提に対し right-sized。「アプリ層の認証・認可は out of scope」は、機微データ非保持と外部エンドユーザー非提供（requirements Out of Scope）に照らし防御可能な判断。秘密の非ハードコード・SSM 経由・ログ非出力（NFR3.1/3.4）は project.md Forbidden/Mandated と整合し、OIDC・ECR scan-on-push は正しく U2/U3 側の責務として本ユニット範囲外。Critical/Major なし。SG 全開放や RDS パブリックアクセスといった throwaway でも実害のある論点は U2 (terraform-infra) の nfr/infra 設計で担保される前提であり、gin-app レビューの範囲外。残る2件は範囲越境の明確化と入力検証の具体化に関する Minor で承認を阻害しない。READY。
