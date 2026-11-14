#!/data/data/com.termux/files/usr/bin/bash
# Termux 上で pocket とショートカット一式をセットアップする。何度実行してもよい（更新にも使える）。
set -euo pipefail
cd "$(dirname "$0")"

REPO=${POCKET_REPO:-Mokkori-Tom/pocket}
BIN=$HOME/bin
# ウィジェットから起動したスクリプトは ~/.bashrc を読まないので、本体は常に PATH にある $PREFIX/bin に置く
DEST=${PREFIX:-/data/data/com.termux/files/usr}/bin/pocket
mkdir -p "$BIN" "$HOME/.shortcuts/tasks" "$HOME/.shortcuts/icons"

echo "==> パッケージ"
pkg install -y termux-api jq curl >/dev/null

echo "==> pocket 本体"
if [ "${1:-}" = "--build" ]; then
	command -v go >/dev/null || pkg install -y golang >/dev/null
	go build -o "$DEST" .
elif ! curl -fsSL -o "$DEST.new" "https://github.com/$REPO/releases/latest/download/pocket-linux-arm64"; then
	echo "    リリースから取得できませんでした。端末上でビルドします"
	command -v go >/dev/null || pkg install -y golang >/dev/null
	go build -o "$DEST" .
else
	mv "$DEST.new" "$DEST"
fi
chmod +x "$DEST"
rm -f "$BIN/pocket"  # 旧バージョンの置き場所
"$DEST" --help >/dev/null

echo "==> ショートカット"
cp -r termux/shortcuts/. "$HOME/.shortcuts/"
chmod 700 "$HOME/.shortcuts" "$HOME/.shortcuts/tasks"
chmod +x "$HOME"/.shortcuts/tasks/* "$HOME"/.shortcuts/メモを見る

echo "==> 共有メニュー (termux-url-opener)"
if [ -e "$BIN/termux-url-opener" ] && ! cmp -s termux/bin/termux-url-opener "$BIN/termux-url-opener"; then
	cp "$BIN/termux-url-opener" "$BIN/termux-url-opener.bak"
	echo "    既存のものは termux-url-opener.bak に退避しました"
fi
cp termux/bin/termux-url-opener "$BIN/"
chmod +x "$BIN/termux-url-opener"

[ -d "$HOME/storage" ] || echo "ヒント: termux-setup-storage を実行すると、メモが内部ストレージの Documents に保存されます"

cat <<'MSG'

完了！ あとはホーム画面を長押し → ウィジェット → Termux:Widget を置いてください。
  クリップを解読 … コピーした JSON / Base64 / UNIX時刻などを読める形に
  クイックメモ   … ダイアログで一行メモ
  メモを見る     … 最近のメモを表示
  共有 → Termux  … ブラウザのページを Markdown リンクとしてコピー
MSG
