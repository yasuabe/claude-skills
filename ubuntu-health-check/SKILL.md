---
name: ubuntu-health-check
description: Ubuntu サーバーの健康診断を実行し、分析レポートを生成する（読み取りのみ）
allowed-tools: Bash, Read
disable-model-invocation: true
---

# Ubuntu Health Check Skill

Ubuntu サーバーの状態を診断し、問題点と推奨アクションをレポートする。
**読み取りのみ。システムへの変更は一切行わない。**

## 手順

### Step 1: 情報収集

`~/.claude/skills/ubuntu-health-check/scripts/collect.sh` を実行して診断データを収集する。

```bash
bash ~/.claude/skills/ubuntu-health-check/scripts/collect.sh 2>&1
```

スクリプトは sudo 不要で、読み取り専用のコマンドのみを実行する。

### Step 2: 分析レポートの生成

収集した出力を以下の観点で分析し、マークダウン形式のレポートを生成する。

#### 分析観点

1. **ディスク使用状況**
   - パーティションごとの使用率（80%超で警告、90%超で危険）
   - inode 使用率
   - HOME 配下の大きなディレクトリ・ファイル
   - `~/.cache` の肥大化チェック
   - APT キャッシュサイズ
   - 古いカーネルの残存

2. **セキュリティ**
   - 保留中のセキュリティアップデート数
   - UFW（ファイアウォール）の状態
   - 不要なリスニングポート
   - Postfix の設定（外部公開していないか）
   - 再起動が必要かどうか（`reboot-required`）

3. **サービス・プロセス**
   - 失敗しているサービス
   - 起動が遅いサービス
   - メモリ・CPU 消費の上位プロセス

4. **メモリ**
   - 物理メモリ・スワップの使用率
   - メモリリークの兆候

5. **コンテナ・Snap**
   - Docker のディスク使用量
   - 停止中・不要なコンテナ
   - Dangling イメージ
   - Snap の無効化された旧リビジョン

6. **ログ・ジャーナル**
   - ジャーナルのディスク使用量
   - 直近24時間のクリティカル/エラーログ

7. **クリーンアップ候補**
   - `dpkg -l` で rc 状態のパッケージ
   - autoremove 対象パッケージ
   - 古い Snap リビジョン
   - Docker 未使用リソース

### Step 3: レポート出力

以下の形式でレポートを出力する:

```
# Ubuntu Health Check Report

**Date:** YYYY-MM-DD
**Host:** hostname
**OS:** Ubuntu XX.XX

## Summary
全体の健康状態を 🟢 Good / 🟡 Attention / 🔴 Action Required で表示

## Findings

### [カテゴリ名]
- **状態:** 🟢/🟡/🔴
- **現状:** 具体的な数値・事実
- **推奨:** 対処が必要な場合のアクション

(各カテゴリを繰り返す)

## Recommended Actions
優先度順にアクションリストをまとめる（コマンド例付き）
```

## 注意事項

- このスキルは**情報収集と分析のみ**を行う。実際の対処（パッケージ削除、設定変更など）はユーザーが判断して実行する。
- `collect.sh` のコマンドが一部失敗しても（権限不足など）、取得できた情報で分析を行う。
- Docker や Snap がインストールされていない場合、そのセクションはスキップされる。
