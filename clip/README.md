# clip

Claude Code のカスタムスキル。会話中に登場した `sudo` コマンドをクリップボードにコピーする。

## 使い方

Claude Code のプロンプトで `/clip` と入力する。直近の会話で言及された `sudo` コマンドが自動的に検出され、クリップボードにコピーされる。

## 要件

- Linux / X11 環境
- `xclip` がインストール済みであること

```bash
sudo apt install xclip
```

## インストール

```bash
git clone https://github.com/yasuabe/claude-skills.git
cd claude-skills
bash install.sh
```
