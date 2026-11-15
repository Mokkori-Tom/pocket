# pocket

Termux のホーム画面ショートカットから使う、Go 製の小さな道具箱。
「Go の CLI をそのままスマホのホームに置ける」ことを試すためのデモ。

**試してみる人へ → [スマホで試す手順（docs/はじめに.md）](docs/はじめに.md)**

| ホーム画面 / 共有メニュー | 動き |
|---|---|
| **クイックメモ** | ダイアログで一行入力 → 日時つきで `pocket-memo.md` に追記 |
| **メモを見る** | 最近 10 件のメモを表示 |
| **クリップを解読** | コピー中の JSON / Base64 / URLエンコード / UNIX時刻 / JWT を自動判別して整形し、クリップボードに戻す |
| **共有 → Termux** | ブラウザで見ているページを `[タイトル](URL)` にしてコピー |

`setup.sh --okf` で、okf（ノートの CLI）用のショートカットも入る。

| okf 用 | 動き |
|---|---|
| **okf検索** | 検索語を Gboard で入力 → 結果一覧から選んで読む（q で一覧に戻る） |
| **okfバンドルを選ぶ** | 内部ストレージのフォルダを一覧でたどってバンドルを選ぶ（場所を変えたときもこれで選び直す） |
| **okf日誌に追記** | Gboard で書いた文を、時刻つき箇条書きで今日の日誌に追記。場所は `OKF_DAILY`（既定 `日記/%Y/%m/%F`）、なければ作成（Templates/daily.md があれば使う） |
| **okf新規ノート** | フォルダを一覧から選び（雑記が先頭）、タイトル・本文・タグを Gboard で入力してノートを作成 |

okf 本体は [Mokkori-Tom/okf](https://github.com/Mokkori-Tom/okf) の ja-human ブランチを、このリポジトリのリリースで arm64 向けにビルドして配っている。
設定は `~/.config/pocket/env`（`OKF_BUNDLE`、`OKF_DAILY`、`OKF_AUTHOR`）。バンドルは「okfバンドルを選ぶ」で選ぶ（setup.sh も共有ストレージの Obsidian 保管庫を探す）。

## セットアップ

```sh
pkg install -y git && git clone https://github.com/Mokkori-Tom/pocket && pocket/setup.sh [--okf]
```

更新は `cd ~/pocket && git pull && ./setup.sh`（一度 `--okf` で入れていれば okf も自動で更新される）。
`--build` を付けるか、リリースが取れないときは端末上でビルドする（golang パッケージを入れる）。

## CLI として

```sh
pocket decode 1763100000          # → UNIX時刻 / 2025-11-14 15:00:00 JST (Fri)
echo '{"a":1}' | pocket decode    # → JSON を整形
pocket link https://go.dev/       # → [The Go Programming Language](https://go.dev/)
pocket memo 牛乳を買う             # 引数なしで最近のメモを表示
```

メモの保存先は `$POCKET_MEMO` → `~/storage/shared/Documents/pocket-memo.md`（`termux-setup-storage` 済みの場合）→ `~/pocket-memo.md` の順。

## Termux 向けに作るときの注意（実機で分かったこと）

- **ショートカットは `~/.bashrc` を読まない。** `~/bin` などに置いたコマンドは見つからない（`command not found`）。コマンドは `$PREFIX/bin` に置く。
- **`~/.bashrc` には触らない。** ble.sh などは `ble-attach` が最後の行である前提なので、末尾に追記すると壊しうる。
- **Android 10 以降、バックグラウンドからはクリップボードを読めない。** `~/.shortcuts/tasks/`（ターミナルを開かない）から `termux-clipboard-get` を呼ぶと空になる。クリップボードを読むものは `~/.shortcuts/` 直下（前面で開く）に置く。
- **ターミナルを開くショートカットには「他のアプリの上に重ねて表示」の許可が要る。** 名前は機種ごとに違う（フローティング表示など）。
- **ショートカットの場所を変えると、ウィジェットは古いパスを呼び続ける**（`FileUtils Error ... not found`）。ウィジェットの 🔄 か置き直しが必要。
- **Termux のターミナルでは日本語入力がつらい。** `termux-dialog` は Android 標準の入力欄なので Gboard がそのまま使える。入力はダイアログで受け、パスのような選べるものは `termux-dialog sheet` の一覧で選ばせる。
- **Termux / Termux:Widget / Termux:API は入手元をそろえる。** 署名が違うと動かない。Termux:API が無いと `termux-*` コマンドは応答せずに止まるので、`timeout` を付けて確かめる。
- **前面のショートカットは、終了後も Termux の画面が残ることがある**（別のセッションがあるとそちらに切り替わる）。結果は `Enterで閉じる` で止めて見せる。

## リリース

`v*` タグを push すると GitHub Actions が `pocket-linux-arm64` と `okf-linux-arm64` をビルドしてリリースに添付する。`setup.sh` はまずこれをダウンロードする。
