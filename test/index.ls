# sankey 的 test case ( 用 @makechart/viewer 的 mctest 跑, 見 README / `npx mctest -h` )
#
# 資料都由固定種子產生, 改這裡會讓全部 snapshot 跟著變.

rnd = mctest.random 7

# 三欄: 來源 -> 轉換 -> 用途 ( 以欄位區分節點 )
stage = (n = 24) ->
  src = <[煤 天然氣 石油 核能 再生能源]>
  via = <[電力 工業熱能 交通燃料 直接燃燒]>
  dst = <[工業 住宅 商業 運輸]>
  pick = (l) -> l[Math.floor(rnd! * l.length)]
  raw: [0 til n].map -> {source: pick(src), via: pick(via), target: pick(dst), value: +(1 + rnd! * 20).toFixed(1)}
  binding:
    path: [{key: \source}, {key: \via}, {key: \target}]
    value: {key: \value, unit: \PJ}

# 兩欄邊列表: 同名即同一節點, 可以接成多層 ( a -> b -> c, 也有跨層的 a -> c )
edges = (list) ->
  raw: list.map -> {from: it.0, to: it.1, value: it.2}
  binding:
    path: [{key: \from}, {key: \to}]
    value: {key: \value}

data =
  stage: stage!
  many: stage 120
  edge: edges [
    <[預算 人事 40]>, <[預算 營運 25]>, <[預算 研發 35]>
    <[人事 薪資 30]>, <[人事 保險 10]>
    <[研發 薪資 20]>, <[研發 設備 15]>
    <[營運 租金 15]>, <[營運 設備 10]>
    <[預算 儲備 5]>
  ]
  # A -> B -> C -> A: 回頭的那條會被丟掉 ( auto 會改用欄位區分 )
  cycle: edges [<[A B 10]>, <[B C 6]>, <[C A 3]>, <[A C 4]>]
  # 有空格的列: a, '', c 就是 a -> c
  gap: do ->
    d = stage 10
    d.raw.2.via = ''
    d.raw.5.via = ''
    d
  # 沒有 value 維度: 每列算 1
  count: do ->
    d = stage 30
    delete d.binding.value
    d
  single: edges [<[A B 1]>]
  empty: {raw: [], binding: stage!binding}

cases = []

for k in <[stage many edge cycle gap count single empty]> =>
  cases.push {name: "data:#k", data: k}

for align in <[left right center]> =>
  cases.push {name: "align:#align", data: \edge, config: {node: {align}}}
for sort in <[value name none]> =>
  cases.push {name: "sort:#sort", data: \stage, config: {node: {sort}}}
for color in <[target gradient none]> =>
  cases.push {name: "link-color:#color", data: \stage, config: {link: {color}}}

cases ++= [
  * name: "merge:name", data: \cycle, config: {node: {merge: \name}}
  * name: "merge:column", data: \edge, config: {node: {merge: \column}}
  * name: "label:off", data: \stage, config: {label: {show: false}}
  * name: "label:no-value", data: \stage, config: {label: {value: false}}
  * name: "node:wide", data: \stage, config: {node: {width: 30, padding: 24}, link: {curvature: 0.2}}

  # 換資料: 舊的淡出、新的長出來 ( 動畫 flush 到終點 )
  * name: "update:new-data", data: \stage
    steps: [(c) -> d = stage 12; c.set-raw d.raw, d.binding]
  # 換 config 重新排版
  * name: "update:align", data: \edge
    steps:
      * (c) ->
          c.config {node: {align: \left}}
          c.parse!; c.bind!; c.resize!; c.render!
]

mctest.suite {
  data, cases, size: [560, 340]
  # 漸層 id 每次都不同
  normalize: [[/sankey-[a-z0-9]+/g, 'sankey-ID']]
}
