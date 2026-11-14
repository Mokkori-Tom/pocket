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

echo "==> okf（Mokkori-Tom/okf の ja-human 版）"
OKF_DEST=${DEST%/pocket}/okf
if [ "${1:-}" = "--build" ] || ! curl -fsSL -o "$OKF_DEST.new" "https://github.com/$REPO/releases/latest/download/okf-linux-arm64"; then
	command -v go >/dev/null || pkg install -y golang >/dev/null
	tmp=$(mktemp -d)
	git clone -q --depth 1 -b ja-human https://github.com/Mokkori-Tom/okf "$tmp"
	(cd "$tmp" && go build -trimpath -ldflags "-s -w -X main.version=ja-human-$(git rev-parse --short HEAD)" -o "$OKF_DEST" ./cmd/okf)
	rm -rf "$tmp"
else
	mv "$OKF_DEST.new" "$OKF_DEST"
fi
chmod +x "$OKF_DEST"
"$OKF_DEST" version

echo "==> 設定 (~/.config/pocket/env)"
CONF=$HOME/.config/pocket/env
mkdir -p "$(dirname "$CONF")"
if [ ! -e "$CONF" ]; then
	# 共有ストレージにある Obsidian の保管庫（.obsidian を含むフォルダ）を探す
	mapfile -t vaults < <(find "$HOME/storage/shared/" -maxdepth 4 -type d -name .obsidian 2>/dev/null | sed 's|/\.obsidian$||')
	{
		echo "# pocket のショートカットが読む設定"
		if [ ${#vaults[@]} -eq 1 ]; then
			echo "OKF_BUNDLE=\"${vaults[0]}\""
		else
			echo "OKF_BUNDLE=\"\"  # ← okf のバンドル（Obsidian の保管庫）のパスを書く"
			for v in "${vaults[@]}"; do echo "#OKF_BUNDLE=\"$v\""; done
		fi
		echo "OKF_AUTHOR=human:tua"
		echo "export OKF_AUTHOR"
	} >"$CONF"
fi
. "$CONF"
if [ -d "${OKF_BUNDLE:-}" ]; then
	echo "    OKF_BUNDLE=$OKF_BUNDLE"
else
	echo "    !! okf のバンドルが決まっていません。$CONF の OKF_BUNDLE を書いてください"
	[ -d "$HOME/storage" ] || echo "    （先に termux-setup-storage が必要です）"
fi

echo "==> ショートカット"
rm -f "$HOME/.shortcuts/tasks/クリップを解読"  # 旧バージョンの置き場所
cp -r termux/shortcuts/. "$HOME/.shortcuts/"
chmod 700 "$HOME/.shortcuts" "$HOME/.shortcuts/tasks"
chmod +x "$HOME"/.shortcuts/tasks/* "$HOME"/.shortcuts/クリップを解読 "$HOME"/.shortcuts/メモを見る "$HOME"/.shortcuts/okf検索

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
  okf検索         … Gboard で検索語を入れ、一覧から選んで読む
  okf今日に追記   … Gboard で書いた文を今日のデイリーノートに追記
  okf新規ノート   … タイトル・本文・タグを Gboard で入れてノートを作成
MSG
