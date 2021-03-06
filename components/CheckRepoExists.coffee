noflo = require 'noflo'
path = require 'path'
uuid = require 'uuid'
projects = require '../src/projects'

payloadToProject = (data) ->
  repoParts = data.payload.repo.split '/'
  payload =
    project:
      id: uuid.v4()
      name: data.payload.repo
      namespace: repoParts[1].replace /^noflo-/, ''
      repo: data.payload.repo
      branch: data.payload.branch
      graphs: []
      components: []
      specs: []
    repo: data.payload.repo
  payload

openMainPayload = ->
  data =
    route: 'main'
    runtime: null
    project: null
    graph: null
    component: null
    nodes: []

findGraph = (name, project) ->
  base = path.basename name, path.extname name
  for graph in project.graphs
    continue unless graph.name is base
    return graph.properties.id
  return null

findComponent = (name, project) ->
  base = path.basename name, path.extname name
  for component in project.components
    continue unless component.name is base
    return component.name
  return null

exports.getComponent = ->
  c = new noflo.Component
  c.inPorts.add 'in',
    datatype: 'object'
  c.outPorts.add 'existing',
    datatype: 'array'
  c.outPorts.add 'new',
    datatype: 'object'
  c.outPorts.add 'openmain',
    datatype: 'array'
  c.process (input, output) ->
    return unless input.hasData 'in'
    data = input.getData 'in'
    unless data.state?.projects?.length
      # No local projects, pass
      output.sendDone
        openmain: openMainPayload()
        new: payloadToProject data
      return

    existing = data.state.projects.filter (project) ->
      return false unless project.repo is data.payload.repo
      if data.payload.branch is 'master' and not project.branch
        # master is default
        return true
      return false unless project.branch is data.payload.branch
      true
    unless existing.length
      output.sendDone
        openmain: openMainPayload()
        new: payloadToProject data
      return

    projects.getProjectHash existing[0], (err, hash) ->
      unless hash
        hash = [
          'project'
          existing[0].id
          existing[0].main
        ]

      if data.payload.component
        # Particular component requested
        component = findComponent data.payload.component, existing[0]
        if component
          hash[2] = 'component'
          hash[3] = component
      if data.payload.graph
        # Particular graph requested
        graph = findGraph data.payload.graph, existing[0]
        if graph
          delete hash[3]
          hash[2] = graph

      output.sendDone
        existing: hash
    return
