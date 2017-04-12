d3 = require '../dist/d3'

class VisualizationCanvasBase extends Backbone.View

  el: '.visualization-graph-component' 

  COLOR_SOLID:
    'solid-1': '#ef9387'
    'solid-2': '#fccf80'
    'solid-3': '#fee378'
    'solid-4': '#d9d070'
    'solid-5': '#82a389'
    'solid-6': '#87948f'
    'solid-7': '#89b5df'
    'solid-8': '#aebedf'
    'solid-9': '#c6a1bc'
    'solid-10': '#f1b6ae'
    'solid-11': '#a8a6a0'
    'solid-12': '#e0deda'
  COLOR_QUALITATIVE:  ['#88b5df', '#fbcf80', '#82a288','#ffebad', '#c5a0bb', '#dfdeda', '#a8a69f', '#ee9286', '#d9d06f', '#f0b6ad']
  COLOR_QUANTITATIVE: ['#fff0c2', '#ffe795', '#fedf69', '#fed63c', '#b5ba7c', '#6d9ebb', '#2482fb', '#2b64c5', '#31458f', '#382759']

  canvas:                 null
  data:                   null
  data_nodes:             []
  data_nodes_visibles:    []
  data_relations:         []
  data_relations_visibles:[]
  force:                  null
  forceDrag:              null
  forceLink:              null
  forceManyBody:          null
  linkedByIndex:          {}
  parameters:             null
  color_scale:            null
  node_active:            null
  node_hovered:           null
  scale_nodes_size:       null
  scale_labels_size:      null
  # Viewport object to store drag/zoom values
  viewport:
    width: 0
    height: 0
    center:
      x: 0
      y: 0
    origin:
      x: 0
      y: 0
    x: 0
    y: 0
    dx: 0
    dy: 0
    offsetnode:
      x: 0
      y: 0
    drag:
      x: 0
      y: 0
    scale: 1
    translate:
      x: 0
      y: 0


  setup: (_data, _parameters) ->
    @parameters = _parameters

    @setupData _data

    @setupViewport()

    @setupForce()

    # Setup Canvas or SVG
    @setupCanvas()

    # set nodes size scale
    @setScaleNodesSize()
  
    # Translate svg
    @rescale()

    # Remove loading class
    @$el.removeClass 'loading'

    ###
    # FPS meter
    fpsMeter = d3.select(@el).append('div')
      .style 'font-family', 'monospace'
      .style 'position', 'absolute'
      .style 'top', '0'
      .style 'padding', '8px'
      .style 'background', 'black'
      .style 'color', 'white'
    ticks = []
    d3.timer (t) ->
      ticks.push t
      if ticks.length > 15
        ticks.shift()
      avgFrameLength = (ticks[ticks.length-1] - ticks[0])/ticks.length
      fpsMeter.html Math.round(1/avgFrameLength*1000) + ' fps'
    ###


  setupData: (data) ->
    @data_nodes              = []
    @data_relations          = []
    @data_relations_visibles = []
    # Setup Nodes
    data.nodes.forEach @addNodeData
    # Setup Relations: change relations source & target N based id to 0 based ids & setup linkedByIndex object
    data.relations.forEach @addRelationData
    # Setup color scale
    @setColorScale()
    # Add linkindex to relations
    #@setLinkIndex()
    #console.log 'current nodes', @data_nodes
    #console.log 'current relations', @data_relations_visibles

  setupViewport: ->
    @viewport.width     = @$el.width()|0
    @viewport.height    = @$el.height()|0
    @viewport.center.x  = (@$el.width()*0.5)|0
    @viewport.center.y  = (@$el.height()*0.5)|0

  setupForce: ->
    # Setup force links
    @forceLink = d3.forceLink()
      .id       (d) -> return d.id
      .distance ()  => return @parameters.linkDistance
    # Setup force many bodys
    @forceManyBody = d3.forceManyBody()
      # (https://github.com/d3/d3-force#manyBody_strength)
      .strength () => return @parameters.linkStrength
      # set maximum distance between nodes over which this force is considered
      # higher values increase performance
      # (https://github.com/d3/d3-force#manyBody_distanceMax)
      .distanceMax 1000
      #.theta      @parameters.theta
    # Setup force simulation
    @force = d3.forceSimulation()
      .force 'link',    @forceLink
      .force 'charge',  @forceManyBody
      .force 'center',  d3.forceCenter(0,0)
      .on    'tick',    @onTick
      #.stop()
    # Reduce number of force ticks until the system freeze
    # (https://github.com/d3/d3-force#simulation_alphaDecay)
    @force.alphaDecay 0.06
    # Setup force drag
    @forceDrag = d3.drag()
      .on 'start',  @onNodeDragStart
      .on 'drag',   @onNodeDragged
      .on 'end',    @onNodeDragEnd

  render: ( restarForce ) ->
    #console.log 'render', restarForce
    @updateNodes()
    @updateRelations()
    @updateForce restarForce

  updateForce: (restarForce) ->
    # update force nodes & links
    @force.nodes @data_nodes
    @force.force('link').links(@data_relations_visibles)
    # restart force
    if restarForce
      @restartForce()
    ###
    # Run statci force layout https://bl.ocks.org/mbostock/1667139
    ticks = Math.ceil(Math.log(@force.alphaMin()) / Math.log(1 - @force.alphaDecay()))
    for i in [0...ticks]
      @force.tick()
    @onTick()
    ###

  restartForce: ->
    @force
      .alpha 0.15
      .restart()

  # Used in visualization-story to update visualization states
  updateData: (nodes, relations) ->
    #console.log 'updateData',nodes, relations
    # Setup disable values in nodes
    @data_nodes_visibles.forEach (node) ->
      node.disabled = nodes.indexOf(node.id) == -1
    # Setup disable values in relations
    @data_relations_visibles.forEach (relation) ->
      relation.disabled = relations.indexOf(relation.id) == -1    
    # update nodes fill & redraw
    @data_nodes_visibles.forEach (d) =>
      @setNodeFill d
    # update relations state & stroke
    @updateRelations()
    @redraw()

  addNodeData: (node) =>
    # check if node is present in @data_nodes
    #console.log 'addNodeData', node.id, node
    if node
      # force empties node_types to null to avoid 2 non-defined types 
      if node.node_type == ''
        node.node_type = null
      @data_nodes.push node
      if node.visible
        @data_nodes_visibles.push node

  addRelationData: (relation) =>
    relation.source = @getNodeById relation.source_id
    relation.target = @getNodeById relation.target_id
    # Add relations with both source & target to data_relations array
    @data_relations.push relation
    # Add relation to data_relations_visibles array if both nodes exist and are visibles
    if relation.source and relation.target and relation.source.visible and relation.target.visible
      @data_relations_visibles.push relation
      @addRelationToLinkedByIndex relation.source_id, relation.target_id

  addRelationToLinkedByIndex: (source, target) ->
    # count number of relations between 2 nodes
    @linkedByIndex[source+','+target] = ++@linkedByIndex[source+','+target] || 1

  ### Chekcout this!!! We don't use it
  # Add a linkindex property to relations
  # Based on https://github.com/zhanghuancs/D3.js-Node-MultiLinks-Node
  setLinkIndex: ->
    # Sort relations
    @data_relations_visibles.sort (a,b) ->
      if a.source_id > b.source_id
        return 1
      else if a.source_id < b.source_id
        return -1
      else 
        if a.target_id > b.target_id
          return 1
        else if a.target_id < b.target_id
          return -1
        else
          return 0
    # set linkindex attr
    @data_relations_visibles.forEach (relation, i) =>
      if i != 0 && @data_relations_visibles[i].source_id == @data_relations_visibles[i-1].source_id && @data_relations_visibles[i].target_id == @data_relations_visibles[i-1].target_id
        @data_relations_visibles[i].linkindex = @data_relations_visibles[i-1].linkindex + 1
      else
        @data_relations_visibles[i].linkindex = 1
  ###

  sortNodes: (a, b) ->
    if a.size > b.size
      return 1
    else if a.size < b.size
      return -1
    else
      return 0

  sortRelations: (a, b) ->
    if a.state > b.state
      return 1
    else if a.state < b.state
      return -1
    else
      return 0

  setColorScale: ->
    if @parameters.nodesColor == 'qualitative' or @parameters.nodesColor == 'quantitative'
      color_scale_domain = @data_nodes.map (d) => return d[@parameters.nodesColorColumn]
      if @parameters.nodesColor == 'qualitative' 
        @color_scale = d3.scaleOrdinal().range @COLOR_QUALITATIVE
        @color_scale.domain _.uniq(color_scale_domain)
        #console.log 'color_scale_domain', _.uniq(color_scale_domain)
      else
        @color_scale = d3.scaleQuantize().range @COLOR_QUANTITATIVE
        # get max scale value avoiding undefined result
        color_scale_max = d3.max(color_scale_domain)
        unless color_scale_max
          color_scale_max = 0
        @color_scale.domain [0, color_scale_max]
        #console.log 'color_scale_domain', d3.max(color_scale_domain)
      # @color_scale = d3.scaleViridis()
      #   .domain([d3.max(color_scale_domain), 0])


  # Resize Methods
  # ---------------

  resize: ->
    #console.log 'VisualizationGraphCanvas resize'
    # Update Viewport attributes
    @viewport.width     = @$el.width()|0
    @viewport.height    = @$el.height()|0
    @viewport.origin.x  = ((@$el.width()*0.5) - @viewport.center.x)|0
    @viewport.origin.y  = ((@$el.height()*0.5) - @viewport.center.y)|0

    # Update canvas
    @canvas.attr 'width', @viewport.width
    @canvas.attr 'height', @viewport.height

    @quadtree.extent [[0, 0], [@viewport.scale*@viewport.width, @viewport.scale*@viewport.height]]
    
    @rescale()
    # Update force size
    #@force.size [@viewport.width, @viewport.height] 


  # Auxiliar Methods
  # ----------------

  getNodeById: (id) ->
    node = @data_nodes.filter (d) -> d.id == id
    return if node.length > 0 then node[0] else null

  areNodesRelated: (a, b) ->
    return @linkedByIndex[a.id + ',' + b.id] || @linkedByIndex[b.id + ',' + a.id] || a.id == b.id

  setNodeSize: (d) ->
    # fixed nodes size 
    if @parameters.nodesSize != 1
      d.size = @parameters.nodesSize
    # nodes size based on number of relations or custom_fields
    else
      val = if d[@parameters.nodesSizeColumn] then d[@parameters.nodesSizeColumn] else 0
      d.size = @scale_nodes_size val

  setNodesRelations: =>
    # initialize relations attribute for each node with zero value
    @data_nodes.forEach (d) =>
      d.relations = 0
    # increment relation attributes for each relation
    @data_relations_visibles.forEach (d) =>
      d.source.relations += 1
      d.target.relations += 1
    
  setScaleNodesSize: =>
    if @parameters.nodesSize != 1
      return
    # set relations attribute in nodes
    if @parameters.nodesSizeColumn == 'relations'
      @setNodesRelations()
    # set node size scale
    if @data_nodes.length > 0
      maxValue = d3.max @data_nodes, (d) => return d[@parameters.nodesSizeColumn]
    else 
      maxValue = 0
    # avoid undefined values
    unless maxValue
      maxValue = 0
    # set nodes size scale
    @scale_nodes_size = d3.scaleLinear()
      .domain [0, maxValue]
      .range [5, 20]
    # set labels size scale
    @scale_labels_size = d3.scaleQuantize()
      .domain [0, maxValue]
      .range [0, 1, 2, 3]

  getImage: (d) ->
    # if image is defined and is an object with image.small.url attribute get that
    if d.image and d.image.small.url
      d.image.small.url
    # if image is defined but is a string get the string
    else if typeof d.image == 'string'
      d.image
    else
      null


module.exports = VisualizationCanvasBase