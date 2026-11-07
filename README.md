# @makechart/sankey

makechart 的 sankey 圖。


## 資料

 - `path` ( 類別, 多欄 ): 一列是一條流向, 相鄰兩格之間是一條連結, 兩端相同的連結合併加總. 空格略過.
   - 兩欄: 當成邊列表 ( from, to ), 同名即同一節點, 可以接成多層.
   - 三欄以上: 每欄一層 ( 例如 來源 -> 轉換 -> 用途 ), 不同欄的同名節點是不同節點.
   - 用 `node.merge` ( `name` / `column` ) 強制指定.
 - `value` ( 數值, 選填 ): 流量. 沒綁就每列算 1.

形成迴圈的連結畫不成由左往右的流, 會被丟掉並在 console 警告.


## 開發

    npm run build             # src -> dist
    npm test                  # 用 @makechart/viewer 跑 test/index.ls, 跟 test/snapshot 比對
    npm run test:serve        # 開 viewer UI 看 case; /playground 可以改設定、資料試玩

改 base / chart 時用 `test:dev`、`test:dev:serve` 連本地的 `../base` 與 `@plotdb/chart`.
