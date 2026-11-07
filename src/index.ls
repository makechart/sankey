module.exports =
  pkg:
    name: 'sankey', version: '0.0.1'
    # lite: 不帶 d3 的 base. 版面自己算 ( 移植 d3-sankey ), 補間走 chart.anim
    extend: {name: "@makechart/base", path: "lite/index.html"}
    dependencies: []
    i18n:
      "zh-TW":
        "path": "流向"
        "value": "數值"
  init: ({root, context, t, pubsub}) ->
    pubsub.fire \init, mod: mod({context, t})

svgns = "http://www.w3.org/2000/svg"
sum = (list, f) -> list.reduce ((a, b) -> a + f(b)), 0

# ---------------------------------------------------------------- graph
# rows: [{path: [a, b, c], value}] -> {nodes, links}. 一列是一條流向, 相鄰兩格之間是一條 link,
# 同樣兩端的 link 合併加總. 空格略過 ( a, '', c 就是 a -> c ).
# by-name: 同名即同一個節點 ( 邊列表, 可以接成多層 ); 否則以欄位區分 ( 每欄一層 )
build = (rows, by-name) ->
  [nodes, links, nh, lh] = [[], [], {}, {}]
  get = (name, col) ->
    id = if by-name => "n:#name" else "#col:#name"
    if !(n = nh[id]) =>
      n = nh[id] = {id, name, col, index: nodes.length, source-links: [], target-links: []}
      nodes.push n
    n
  for r in rows
    seq = r.path
      .map (n, i) -> {n: (if n? => "#n".trim! else ''), i}
      .filter -> it.n
    for j from 0 til seq.length - 1
      [s, tg] = [get(seq[j].n, seq[j].i), get(seq[j + 1].n, seq[j + 1].i)]
      key = "#{s.id}>#{tg.id}"
      if !(l = lh[key]) =>
        l = lh[key] = {key, source: s, target: tg, value: 0, index: links.length}
        links.push l
      l.value += r.value
  # 迴圈 ( 包含自己連自己 ) 沒辦法畫成由左往右的流, 回頭的那幾條丟掉
  state = {}
  out = {}
  links.map (l) -> out.[][l.source.id].push l
  visit = (n) ->
    state[n.id] = 1
    for l in (out[n.id] or [])
      if state[l.target.id] == 1 => l.cycle = true
      else if !state[l.target.id] => visit l.target
    state[n.id] = 2
  nodes.map (n) -> if !state[n.id] => visit n
  cycle = links.filter (.cycle) .length
  links = links.filter -> !it.cycle
  links.map (l, i) ->
    l.index = i
    l.source.source-links.push l
    l.target.target-links.push l
  # 沒有任何連結的節點 ( 整列只有一格 ) 不畫
  nodes = nodes.filter -> it.source-links.length or it.target-links.length
  nodes.map (n, i) -> n.index = i
  {nodes, links, cycle}

# ---------------------------------------------------------------- layout
# 移植自 d3-sankey 0.12 ( ISC, Mike Bostock ). 差別:
#  - 迴圈在 build 時已經拿掉, 這裡不會丟例外
#  - 以欄位區分節點時, 層就是欄位 ( align 不作用 )
align-fn =
  left: (n) -> n.depth
  right: (n, x) -> x - 1 - n.height
  justify: (n, x) -> if n.source-links.length => n.depth else x - 1
  center: (n) ->
    if n.target-links.length => n.depth
    else if n.source-links.length => Math.min.apply(Math, n.source-links.map -> it.target.depth) - 1
    else 0

by-breadth = (a, b) -> a.y0 - b.y0
by-source = (a, b) -> (by-breadth(a.source, b.source)) or (a.index - b.index)
by-target = (a, b) -> (by-breadth(a.target, b.target)) or (a.index - b.index)

layout = ({nodes, links}, opt) ->
  {x0, y0, x1, y1, dx, dy, align, sort, iterations, by-column} = opt
  for n in nodes
    n.value = Math.max(sum(n.source-links, (.value)), sum(n.target-links, (.value)))
  # depth / height: 最長路徑. 迴圈已經拿掉, 一定會收斂
  walk = (key, next) ->
    [cur, x] = [new Set(nodes), 0]
    while cur.size
      nxt = new Set!
      cur.forEach (n) ->
        n[key] = x
        next(n).map -> nxt.add it
      x++
      cur = nxt
  walk \depth, (n) -> n.source-links.map (.target)
  walk \height, (n) -> n.target-links.map (.source)

  # 分層
  if by-column =>
    cols = Array.from(new Set(nodes.map (.col))).sort (a, b) -> a - b
    layer = (n) -> cols.indexOf n.col
    x = cols.length
  else
    x = Math.max.apply(Math, [0] ++ nodes.map (.depth)) + 1
    f = align-fn[align] or align-fn.justify
    layer = (n) -> Math.floor f(n, x)
  kx = if x > 1 => (x1 - x0 - dx) / (x - 1) else 0
  columns = [[] for i from 0 til x]
  for n in nodes
    i = layer(n) >? 0 <? (x - 1)
    n.layer = i
    n.x0 = x0 + i * kx
    n.x1 = n.x0 + dx
    columns[i].push n
  columns = columns.filter (.length)
  if sort => columns.map -> it.sort sort
  resort = sort == undefined

  # 縱向的初始位置
  py = Math.min(dy, (y1 - y0) / ((Math.max.apply(Math, columns.map (.length)) - 1) or 1))
  ky = Math.min.apply Math, columns.map (c) -> (y1 - y0 - (c.length - 1) * py) / (sum(c, (.value)) or 1)
  ky = ky >? 0
  reorder-links = (ns) ->
    for n in ns
      n.source-links.sort by-target
      n.target-links.sort by-source
  for c in columns
    y = y0
    for n in c
      n.y0 = y
      n.y1 = y + n.value * ky
      y = n.y1 + py
      for l in n.source-links => l.width = l.value * ky
    y = (y1 - y + py) / (c.length + 1)
    c.map (n, i) ->
      n.y0 += y * (i + 1)
      n.y1 += y * (i + 1)
    if resort => reorder-links c

  reorder-node-links = (n) ->
    if !resort => return
    for l in n.target-links => l.source.source-links.sort by-target
    for l in n.source-links => l.target.target-links.sort by-source
  # 讓 source -> target 這條連結水平的 target.y0
  target-top = (s, tg) ->
    y = s.y0 - (s.source-links.length - 1) * py / 2
    for l in s.source-links
      if l.target == tg => break
      y += l.width + py
    for l in tg.target-links
      if l.source == s => break
      y -= l.width
    y
  source-top = (s, tg) ->
    y = tg.y0 - (tg.target-links.length - 1) * py / 2
    for l in tg.target-links
      if l.source == s => break
      y += l.width + py
    for l in s.source-links
      if l.target == tg => break
      y -= l.width
    y
  down = (ns, y, i, alpha) ->
    while i < ns.length
      n = ns[i]
      d = (y - n.y0) * alpha
      if d > 1e-6
        n.y0 += d
        n.y1 += d
      y = n.y1 + py
      i++
  up = (ns, y, i, alpha) ->
    while i >= 0
      n = ns[i]
      d = (n.y1 - y) * alpha
      if d > 1e-6
        n.y0 -= d
        n.y1 -= d
      y = n.y0 - py
      i--
  collide = (ns, alpha) ->
    i = ns.length .>>. 1
    sub = ns[i]
    up ns, sub.y0 - py, i - 1, alpha
    down ns, sub.y1 + py, i + 1, alpha
    up ns, y1, ns.length - 1, alpha
    down ns, y0, 0, alpha
  relax = (c, alpha, beta, fwd) ->
    for n in c
      [y, w] = [0, 0]
      if fwd
        for l in n.target-links
          v = l.value * (n.layer - l.source.layer)
          y += target-top(l.source, n) * v
          w += v
      else
        for l in n.source-links
          v = l.value * (l.target.layer - n.layer)
          y += source-top(n, l.target) * v
          w += v
      if !(w > 0) => continue
      d = (y / w - n.y0) * alpha
      n.y0 += d
      n.y1 += d
      reorder-node-links n
    if resort => c.sort by-breadth
    collide c, beta
  for i from 0 til iterations
    alpha = Math.pow 0.99, i
    beta = Math.max(1 - alpha, (i + 1) / iterations)
    for j from columns.length - 2 to 0 by -1 => relax columns[j], alpha, beta, false
    for j from 1 til columns.length => relax columns[j], alpha, beta, true

  # 每條連結在兩端的位置 ( 線的中心 )
  for n in nodes
    [a, b] = [n.y0, n.y0]
    for l in n.source-links
      l.y0 = a + l.width / 2
      a += l.width
    for l in n.target-links
      l.y1 = b + l.width / 2
      b += l.width
  {columns, ky}

# ---------------------------------------------------------------- mod
mod = ({context, t}) ->
  {chart} = context
  {format, anim: {join}} = chart.utils
  sample: ->
    # 能源流向: 來源 -> 轉換 -> 用途
    flows = [
      <[煤 電力 工業 30]>, <[煤 電力 住宅 18]>, <[煤 電力 商業 12]>, <[煤 工業熱能 工業 15]>
      <[天然氣 電力 住宅 10]>, <[天然氣 電力 商業 9]>, <[天然氣 工業熱能 工業 14]>, <[天然氣 直接燃燒 住宅 8]>
      <[石油 交通燃料 運輸 40]>, <[石油 工業熱能 工業 6]>, <[石油 直接燃燒 商業 3]>
      <[核能 電力 工業 7]>, <[核能 電力 住宅 5]>
      <[再生能源 電力 住宅 8]>, <[再生能源 電力 商業 6]>, <[再生能源 電力 工業 4]>
    ]
    raw: flows.map -> {source: it.0, via: it.1, target: it.2, value: +it.3}
    binding:
      path: [{key: \source}, {key: \via}, {key: \target}]
      value: {key: \value, unit: \PJ}
  config: do ->
    c = chart.utils.config.from {preset: \default, tip: \tip, label: \label}
    # 去掉尾端的 0: 6.00 -> 6, 14.0 -> 14
    c.label.format.default = c.tip.format.default = \.3~s
    c.label <<<
      show: type: \boolean, default: true
      value: type: \boolean, default: true
    c <<<
      node:
        width: type: \number, default: 12, min: 1, max: 100, step: 1
        padding: type: \number, default: 10, min: 0, max: 100, step: 1
        align: type: \choice, values: <[justify left right center]>, default: \justify
        sort: type: \choice, values: <[auto value name none]>, default: \auto
        # auto: 只有兩欄時當邊列表 ( 同名同一節點 ), 接成迴圈就改以欄位區分; 三欄以上以欄位區分
        merge: type: \choice, values: <[auto name column]>, default: \auto
        iterations: type: \number, default: 6, min: 0, max: 32, step: 1
      link:
        color: type: \choice, values: <[source target gradient none]>, default: \source
        opacity: type: \number, default: 0.4, min: 0, max: 1, step: 0.05
        curvature: type: \number, default: 0.5, min: 0, max: 1, step: 0.05
  dimension:
    path: {type: \C, multiple: true, name: "path", priority: 1}
    value: {type: \R, name: "value", priority: 2}
  init: ->
    @tint = new chart.utils.tint!
    @g = view: @layout.get-group \view
    mk = (tag, cls) ~>
      n = document.createElementNS svgns, tag
      if cls => n.setAttribute \class, cls
      @g.view.appendChild n
    @g <<<
      defs: mk \defs
      link: mk \g, \links
      node: mk \g, \nodes
      label: mk \g, \labels
    @g.link.setAttribute \fill, \none
    # 漸層的 id 要在整頁唯一
    @uid = "sankey-#{Math.random!toString(36).substring(2)}"

    # hover: 節點亮出進出它的連結, 連結只亮自己
    hl = (e) ~>
      d = e.target.__data__
      if !(d and (d.source-links or d.source)) => return clear!
      ls = if d.source => [d] else d.source-links ++ d.target-links
      Array.from(@g.link.childNodes).map (n) -> n.classList.toggle \hl, (n.__data__ in ls)
      @g.view.classList.add \sankey-hover
    clear = ~> @g.view.classList.remove \sankey-hover
    @g.view.addEventListener \mouseover, hl
    @g.view.addEventListener \mouseout, clear

    @fmt-v = (v) ~>
      if isNaN(v) => return '-'
      f = format.from((@cfg.tip or {}).format or \.3~s)
      "#{f v}#{(@binding.value or {}).unit or ''}"
    @tip = new chart.utils.tip {
      root: @root
      accessor: ({evt}) ~>
        if !(evt.target and d = evt.target.__data__) => return null
        if d.source =>
          p = if d.source.value => "#{(100 * d.value / d.source.value).toFixed(1)}%" else ''
          return {group: '', name: "#{d.source.name} → #{d.target.name}", value: @fmt-v(d.value), value-alt: p}
        if d.source-links => return {group: '', name: d.name, value: @fmt-v(d.value), value-alt: ''}
        null
      range: ~> @layout.get-node \view .getBoundingClientRect!
    }

  destroy: -> if @tip => @tip.destroy!

  parse: ->
    has-value = !!@binding.value
    rows = @data
      .map (d) -> {path: (d.path or []), value: (if has-value => +d.value else 1)}
      .filter -> it.path.length and it.value > 0 and isFinite(it.value)
    ncol = Math.max.apply(Math, [0] ++ rows.map (.path.length))
    merge = (@cfg.node or {}).merge or \auto
    by-name = if merge == \auto => ncol <= 2 else merge == \name
    @graph = build rows, by-name
    if merge == \auto and by-name and @graph.cycle => @graph = build rows, (by-name = false)
    @by-column = !by-name
    if @graph.cycle => console.warn "[@makechart/sankey] #{@graph.cycle} link(s) dropped for forming a cycle"

  resize: ->
    @tip.toggle(if @cfg.{}tip.enabled? => @cfg.tip.enabled else true)
    if @cfg.palette => @tint.set @cfg.palette
    @layout.update false
    box = @layout.get-box \view
    cfg = @cfg.node or {}
    sort = switch cfg.sort
    | \value => (a, b) -> (b.value - a.value) or (a.index - b.index)
    | \name => (a, b) -> (if a.name < b.name => -1 else if a.name > b.name => 1 else 0) or (a.index - b.index)
    | \none => (a, b) -> a.index - b.index
    | otherwise => undefined
    layout @graph, {
      x0: 0, y0: 0, x1: box.width, y1: box.height
      dx: cfg.width ? 12
      dy: cfg.padding ? 10
      align: cfg.align, sort
      iterations: cfg.iterations ? 6
      by-column: @by-column
    }
    @box = box

  render: ->
    {graph: {nodes, links}, tint, cfg, box} = @
    lcfg = cfg.link or {}
    tween = (n, attrs, opt) ~> @anim.tween n, attrs, opt
    fade-out = (n) -> tween n, {opacity: 0}, {remove: true}
    color = (n) -> tint.get n.name
    # 不同的連結可以有一樣的 key 字元, id 一律用流水號
    @gid = @gid or {map: {}, n: 0}
    gid = (l) ~> "#{@uid}-#{@gid.map[l.key] ?= @gid.n++}"

    # 漸層 ( link.color = gradient )
    grads = if lcfg.color == \gradient => links else []
    gj = join root: @g.defs, tag: \linearGradient, cls: \grad, data: grads, key: (.key)
    gj.exit.map -> it.parentNode.removeChild it
    gj.nodes.map (n) ->
      l = n.__data__
      n.setAttribute \id, gid(l)
      n.setAttribute \gradientUnits, \userSpaceOnUse
      if !n.childNodes.length => [0 1].map ->
        s = n.appendChild document.createElementNS(svgns, \stop)
        s.setAttribute \offset, "#{it * 100}%"
      tween n, {x1: l.source.x1, x2: l.target.x0}
      [l.source, l.target].map (d, i) -> tween n.childNodes[i], {"stop-color": color(d)}

    k = lcfg.curvature ? 0.5
    path = (l) ->
      [xa, xb] = [l.source.x1, l.target.x0]
      [c0, c1] = [xa + (xb - xa) * k, xb - (xb - xa) * k]
      "M#xa,#{l.y0}C#c0,#{l.y0} #c1,#{l.y1} #xb,#{l.y1}"
    stroke = (l) ->
      switch lcfg.color
      | \target => color l.target
      | \gradient => "url(\##{gid l})"
      | \none => \currentColor
      | otherwise => color l.source
    op = lcfg.opacity ? 0.4

    lj = join root: @g.link, tag: \path, cls: \link, data: links, key: (.key)
    lj.exit.map fade-out
    lj.enter.map (n) ->
      n.setAttribute \d, path(n.__data__)
      n.setAttribute \stroke-opacity, 0
    lj.nodes.map (n) ->
      l = n.__data__
      # 漸層不能補間, 直接換
      if lcfg.color in <[gradient none]> => n.setAttribute \stroke, stroke(l)
      tween n, {
        d: path(l)
        "stroke-width": l.width >? 1
        "stroke-opacity": op
      } <<< (if lcfg.color in <[gradient none]> => {} else {stroke: stroke(l)})

    nj = join root: @g.node, tag: \rect, cls: \data, data: nodes, key: (.id)
    nj.exit.map fade-out
    nj.enter.map (n) ->
      d = n.__data__
      n.setAttribute \x, d.x0
      n.setAttribute \width, d.x1 - d.x0
      n.setAttribute \y, (d.y0 + d.y1) / 2
      n.setAttribute \height, 0
    nj.nodes.map (n) ->
      d = n.__data__
      tween n, {x: d.x0, y: d.y0, width: d.x1 - d.x0, height: (d.y1 - d.y0) >? 1, fill: color(d)}

    # 標籤: 左半邊的放節點右側, 右半邊的放左側 ( 最後一欄的字就不會超出去 )
    lb = cfg.label or {}
    fmt = format.from(lb.format or \.3~s)
    unit = (@binding.value or {}).unit or ''
    show-value = lb.value and !!@binding.value
    labels = if lb.show == false => [] else nodes
    tj = join root: @g.label, tag: \text, cls: \sankey-label, data: labels, key: (.id)
    tj.exit.map fade-out
    pos = (d) ->
      left = d.x0 < box.width / 2
      {left, x: (if left => d.x1 + 6 else d.x0 - 6), y: (d.y0 + d.y1) / 2}
    # 新進場的直接放在終點, 只淡入 ( 沒設 x / y 的話會從左上角滑進來 )
    tj.enter.map (n) ->
      p = pos n.__data__
      n.setAttribute \x, p.x
      n.setAttribute \y, p.y
      n.setAttribute \opacity, 0
    tj.nodes.map (n) ->
      d = n.__data__
      p = pos d
      n.setAttribute \text-anchor, if p.left => \start else \end
      n.setAttribute \dy, \.35em
      n.textContent = d.name + (if show-value => " #{fmt d.value}#{unit}" else '')
      tween n, {x: p.x, y: p.y, opacity: 1}
