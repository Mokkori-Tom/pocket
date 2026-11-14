# pocket

Termux のホーム画面ショートカットから使う、Go 製の小さな道具箱。
「Go の CLI をそのままスマホのホームに置ける」ことを試すためのデモ。

| ホーム画面 / 共有メニュー | 動き |
|---|---|
| **クリップを解読** | コピー中の JSON / Base64 / URLエンコード / UNIX時刻 / JWT を自動判別して整形し、クリップボードに戻して通知 |
| **クイックメモ** | ダイアログで一行入力 → 日時つきで `pocket-memo.md` に追記 |
| **メモを見る** | 最近 10 件のメモを表示 |
| **共有 → Termux** | ブラウザで見ているページを `[タイトル](URL)` にしてコピー |

## セットアップ（Android）

1. F-Droid から **Termux / Termux:Widget / Termux:API** を入れる（入手元はそろえる）
2. Termux で:
   ```sh
   pkg install -y git && git clone https://github.com/Mokkori-Tom/pocket && pocket/setup.sh
   ```
3. ホーム画面を長押し → ウィジェット → Termux:Widget

更新は `cd pocket && git pull && ./setup.sh`。
リリースが無い場合や `./setup.sh --build` のときは端末上でビルドする（golang パッケージを入れる）。

## CLI として

```sh
pocket decode 1763100000          # → UNIX時刻 / 2025-11-14 15:00:00 JST (Fri)
echo '{"a":1}' | pocket decode    # → JSON を整形
pocket link https://go.dev/       # → [The Go Programming Language](https://go.dev/)
pocket memo 牛乳を買う             # 引数なしで最近のメモを表示
```

メモの保存先は `$POCKET_MEMO` → `~/storage/shared/Documents/pocket-memo.md`（`termux-setup-storage` 済みの場合）→ `~/pocket-memo.md` の順。

## リリース

`v*` タグを push すると GitHub Actions が `pocket-linux-arm64` をビルドしてリリースに添付する。`setup.sh` はまずこれをダウンロードする。
