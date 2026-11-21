# Change Logs

## v0.0.4

 - add `tabinfo`: descriptions ( en / zh-TW ) of the config sections, shown on the section tabs in the makechart style panel ( needs @plotdb/chart >= 3.17.0 )

## v0.0.3

 - add `desc` ( en / zh-TW ) to the config items, shown under the label in the makechart style panel

## v0.0.2

 - use English in sample data

## v0.0.1

 - init release: sankey diagram on the lite base ( no d3 ). layout is ported from d3-sankey 0.12,
   tweens go through `chart.anim`
 - requires `@makechart/base` >= 0.2.0 ( `lite/index.html` )
 - `path` dimension takes 2+ columns: two columns are read as an edge list ( same name = same node,
   so it can chain into multiple levels ), three or more are read as stages ( one layer per column ).
   `node.merge` overrides this
 - links forming a cycle are dropped with a warning; under `node.merge = auto` an edge list with a
   cycle falls back to per-column nodes
 - config: node width / padding / align / sort / iterations, link color ( source / target / gradient /
   none ), opacity, curvature, label show / value / format
 - hover a node to highlight its links, hover a link to highlight itself; tip shows value and the
   share of the source node
