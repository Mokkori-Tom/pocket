#!/data/data/com.termux/files/usr/bin/bash
# Termux 上で pocket とショートカット一式をセットアップする。何度実行してもよい（更新にも使える）。
#
#   ./setup.sh          基本の道具（クリップを解読・クイックメモ・メモを見る・共有メニュー）
#   ./setup.sh --okf    okf のショートカットも入れる（一度入れれば、以降の更新では自動で入る）
#   ./setup.sh --build  ダウンロードせず端末上でビルドする
set -euo pipefail
cd "$(dirname "$0")"

WITH_OKF=0 BUILD=0
for a in "$@"; do
	case $a in
	--okf) WITH_OKF=1 ;;
	--build) BUILD=1 ;;
	*) echo "不明なオプション: $a"; exit 2 ;;
	esac
done

if [[ ${PREFIX:-} != */com.termux/* ]]; then
	echo "Termux の中で実行してください"; exit 1
fi

REPO=${POCKET_REPO:-Mokkori-Tom/pocket}
BIN=$HOME/bin
# ウィジェットから起動したスクリプトは ~/.bashrc を読まないので、コマンドは常に PATH にある $PREFIX/bin に置く。
# 逆に ~/.bashrc は（ble.sh などの設定を壊さないよう）一切触らない。
PBIN=$PREFIX/bin
CONF=$HOME/.config/pocket/env
mkdir -p "$BIN" "$HOME/.shortcuts/tasks" "$HOME/.shortcuts/icons" "$(dirname "$CONF")"

# 前回 okf を入れていれば、今回も入れる
if [ -e "$CONF" ] && grep -q '^OKF_BUNDLE="..*"' "$CONF"; then WITH_OKF=1; fi

# fetch <リリースのファイル名> <置き場所>: リリースから取ってくる。失敗したら 1 を返す
fetch() {
	[ $BUILD = 1 ] && return 1
	curl -fsSL -o "$2.new" "https://github.com/$REPO/releases/latest/download/$1" && mv "$2.new" "$2" && chmod +x "$2"
}
need_go() { command -v go >/dev/null || pkg install -y golang >/dev/null; }

echo "==> 内部ストレージへのアクセス"
if [ ! -d "$HOME/storage/shared" ]; then
	echo "    許可のダイアログが出たら「許可」を押してください"
	termux-setup-storage
	for _ in $(seq 30); do [ -d "$HOME/storage/shared" ] && break; sleep 2; done
	[ -d "$HOME/storage/shared" ] || echo "    !! 許可されませんでした。メモは Termux の中（~/pocket-memo.md）に保存されます"
fi

echo "==> パッケージ"
pkg install -y termux-api jq curl >/dev/null
cp termux/cmd/* "$PBIN/" # pocket-pick-dir, pocket-setconf
chmod +x "$PBIN"/pocket-pick-dir "$PBIN"/pocket-setconf

echo "==> Termux:API アプリの確認"
# アプリが無い（または入手元が違って署名が合わない）と termux-* コマンドは応答しないまま止まる
if timeout 15 termux-toast "pocket をセットアップしています" 2>/dev/null; then
	api_ok=1
else
	api_ok=0
	echo "    !! 応答がありません（最後に説明を表示します）"
fi
# 画面の一覧から選んでもらえるのは、Termux:API が動いていて内部ストレージを読めるときだけ
can_pick() { [ $api_ok = 1 ] && [ -d "$HOME/storage/shared" ]; }

echo "==> pocket 本体"
if ! fetch pocket-linux-arm64 "$PBIN/pocket"; then
	echo "    端末上でビルドします（少し時間がかかります）"
	need_go
	go build -o "$PBIN/pocket" .
fi
rm -f "$BIN/pocket" # 古い版の置き場所
pocket --help >/dev/null

if [ $WITH_OKF = 1 ]; then
	echo "==> okf（Mokkori-Tom/okf の ja-human 版）"
	if ! fetch okf-linux-arm64 "$PBIN/okf"; then
		need_go
		tmp=$(mktemp -d)
		git clone -q --depth 1 -b ja-human https://github.com/Mokkori-Tom/okf "$tmp"
		(cd "$tmp" && go build -trimpath -ldflags "-s -w -X main.version=ja-human-$(git rev-parse --short HEAD)" -o "$PBIN/okf" ./cmd/okf)
		rm -rf "$tmp"
	fi
	okf version

	if ! grep -q 'OKF_DAILY' "$CONF" 2>/dev/null; then
		{
			echo "#export OKF_AUTHOR=human:名前  # ノートの作成者として記録される"
			echo "#OKF_DAILY=\"日記/%Y/%m/%F\"     # 日誌の場所（date の書式）。バンドル直下なら \"%F\""
		} >>"$CONF"
	fi
	OKF_BUNDLE=
	. "$CONF"
	if [ ! -d "${OKF_BUNDLE:-}" ] && can_pick; then
		echo "    okf のバンドル（ノートのフォルダ）を、画面に出る一覧から選んでください"
		if dir=$(pocket-pick-dir "okf のバンドルを選ぶ" "${OKF_BUNDLE:-}"); then
			pocket-setconf OKF_BUNDLE "$dir"
			OKF_BUNDLE=$dir
		fi
	fi
	if [ -d "${OKF_BUNDLE:-}" ]; then
		echo "    OKF_BUNDLE=$OKF_BUNDLE"
	else
		echo "    !! okf のバンドルが決まっていません。あとでウィジェットの「okfバンドルを選ぶ」で選んでください"
	fi
fi

echo "==> メモの保存先"
POCKET_MEMO=
. "$CONF" 2>/dev/null || true
if [ -z "${POCKET_MEMO:-}" ] && can_pick; then
	docs=$HOME/storage/shared/Documents
	echo "    画面に出る選択肢から選んでください"
	idx=$(termux-dialog sheet -t "クイックメモの保存先" -v "Documents フォルダ（おすすめ）,自分で選ぶ（Google ドライブや同期フォルダなど）" | jq -r '.index // empty')
	if [ "$idx" = 1 ] && dir=$(pocket-pick-dir "メモを保存するフォルダ"); then
		POCKET_MEMO=$dir/pocket-memo.md
	else
		mkdir -p "$docs"
		POCKET_MEMO=$docs/pocket-memo.md
	fi
	pocket-setconf POCKET_MEMO "$POCKET_MEMO"
fi
echo "    ${POCKET_MEMO:-$(pocket memo-path)}（ウィジェットの「メモの保存先を選ぶ」で変えられます）"

echo "==> ショートカット"
rm -f "$HOME/.shortcuts/tasks/クリップを解読" # 古い版の置き場所（バックグラウンドではクリップボードを読めない）
rm -f "$HOME/.shortcuts/tasks/okf今日に追記"  # okf日誌に追記 の古い名前
cp -r termux/shortcuts/. "$HOME/.shortcuts/"
if [ $WITH_OKF = 1 ]; then cp -r termux/okf-shortcuts/. "$HOME/.shortcuts/"; fi
chmod 700 "$HOME/.shortcuts" "$HOME/.shortcuts/tasks"
find "$HOME/.shortcuts" -type f ! -path '*/icons/*' -exec chmod +x {} +

echo "==> 共有メニュー (termux-url-opener)"
if [ -e "$BIN/termux-url-opener" ] && ! cmp -s termux/bin/termux-url-opener "$BIN/termux-url-opener"; then
	cp "$BIN/termux-url-opener" "$BIN/termux-url-opener.bak"
	echo "    既存のものは termux-url-opener.bak に退避しました"
fi
cp termux/bin/termux-url-opener "$BIN/"
chmod +x "$BIN/termux-url-opener"

echo
if [ $api_ok = 1 ]; then
	termux-toast "pocket のセットアップが終わりました"
	echo "完了！"
else
	cat <<'MSG'
!! Termux:API アプリから応答がありません。
   F-Droid から Termux:API を入れてください。Termux 本体と入手元（F-Droid / GitHub）が
   違うと動きません。Google Play 版の Termux が入っている場合は、全部 F-Droid 版に入れ直してください。
MSG
fi
cat <<MSG

残りの手順（初回のみ）:
  1. 設定 → アプリ → Termux → 「他のアプリの上に重ねて表示」を許可
     （機種によって「フローティング表示」「ポップアップ表示」などの名前です）
  2. ホーム画面を長押し → ウィジェット → Termux:Widget を置く
     更新したあとは、ウィジェットの 🔄 を押すか置き直してください
MSG
