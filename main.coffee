require "cornerstone"
Uploader = require "s3-uploader"

log = console.log.bind(console)

animate = (item, prop, value) ->
  initial = item[prop]
  t = 15

  step = 0
  steps = 200
  inc = (value - initial) / steps

  doStep = ->
    step += 1

    item[prop] = initial + inc * step

    if step <= steps
      setTimeout doStep, t

  doStep()

saveBlob = (policy, path, blob, cacheControl=0) ->
  uploader = Uploader(policy)
  uploader.upload
    key: path
    blob: blob
    cacheControl: cacheControl

readFile = (file, method="readAsText") ->
  return new Promise (resolve, reject) ->
    reader = new FileReader()

    reader.onloadend = ->
      resolve(reader.result)
    reader.onerror = reject
    reader[method](file)

getJSON = (path, options={}) ->
  getBlob(path, options)
  .then readFile
  .then JSON.parse

getBlob = (path, options={}) ->
  new Promise (resolve, reject) ->

    xhr = new XMLHttpRequest()
    xhr.open('GET', path, true)
    xhr.responseType = "blob"

    headers = options.headers
    if headers
      Object.keys(headers).forEach (header) ->
        value = headers[header]
        xhr.setRequestHeader header, value

    xhr.onload = (e) ->
      if (200 <= this.status < 300) or this.status is 304
        try
          resolve this.response
        catch error
          reject error
      else
        reject e

    xhr.onerror = reject
    xhr.send()

fetchPolicy = (token) ->
  getJSON "http://api.whimsy.space/policy.json",
    headers:
      Authorization: token

indexPage = (pkg, mainScript) ->
  """
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8">
        #{dependencyScripts(pkg.remoteDependencies)}
      </head>
      <body>
        #{mainScript}
      </body>
    </html>
  """

# `makeScript` returns a string representation of a script tag that has a src
# attribute.
makeScript = (src) ->
  "<script src=#{JSON.stringify(src)}><\/script>"

# `dependencyScripts` returns a string containing the script tags that are the
# remote script dependencies of this build.
dependencyScripts = (remoteDependencies=[]) ->
  remoteDependencies.map(makeScript).join("\n")

Postmaster = require "postmaster"

postmaster = Postmaster()

music = new Audio
music.autoplay = true
music.volume = 0.0
music.src = "https://s3.amazonaws.com/whimsyspace-databucket-1g3p6d9lcl6x1/danielx/data/K_fOqqpYYfEAJgWkUNlFmg5WZ3YmN5iPcEfVhN3emvs"
document.head.appendChild music

animate music, "volume", 0.1

messageIndex = 0
messages = [
  "Let's create something together"
  "Condensing the clouds"
  "Testing RAM"
  "Testing CPU"
  "Testing Primary Disk"
  "Greasing the network"
  "Polishing the servers"
  "Sharpening Claws"
  "Reticulating splines"
  "Pixelating the pixels"
  "Initializing fun"
  "Awaiting planetary alignment"
  "Rocket boosters ignited"
  "Deflecting solar flares"
  "Drumroll please"
]

model =
  email: Observable "duder@whimsy.space"
  domain: Observable "awesome"
  token: Observable ""
  status: Observable ""
  progressVisible: Observable false
  progress: Observable 0
  statusMessage: Observable messages.wrap(messageIndex)
  step1: (e) ->
    e.preventDefault()
    register(@email(), @domain())
  step2: (e) ->
    e.preventDefault()
    publish(@token())
  step3: (e) ->
    e.preventDefault()

Template = require "./template"
Template2 = require "./template2"
Template3 = require "./template3"
Template4 = require "./template4"
document.body.appendChild(Template(model))

register = (email, domain) ->
  model.progressVisible(true)

  $.post "http://api.whimsy.space/register",
    email: email
    domain: domain
  .done (data, status, xhr) ->
    document.body.innerHTML = ""
    document.body.appendChild(Template2(model))

    animate music, "volume", 0.2

  .fail (xhr, status) ->
    console.log 'fail', arguments
  .always ->
    model.progressVisible(false)

publish = (token) ->
  animate music, "volume", 0.3

  model.progressVisible(true)
  cleanup = ->
    model.progressVisible(false)

  fetchPolicy(token)
  .then (policy) ->
    # Save index page
    p1 = postmaster.invokeRemote "system", "exec", "return system.PACKAGE"
    .then (pkg) ->
      console.log "Recieved package", pkg

      launcher = """
        var fsURL = "index.json";
        var system = require("./main");
        system.netBoot(fsURL);
      """
      wrapper = require('require').packageWrapper(pkg, launcher)
      mainScript = "<script>#{wrapper}<\/script>"

      htmlBlob = new Blob [indexPage(pkg, mainScript)], type: "text/html"
      saveBlob(policy, "index.html", htmlBlob)
    .then log

    # Save filesystem
    p2 = postmaster.invokeRemote "system", "exec", "return system.filesystem().I.files"
    .then (fs) ->
      console.log fs
      fsBlob = new Blob [JSON.stringify(files: fs)], type: "application/json"
      saveBlob(policy, "index.json", fsBlob)
    .then log

    Promise.all([p1, p2])
  .then ->
    cleanup()
    show3()
  .catch (e) ->
    cleanup()

show3 = ->
  animate music, "volume", 0.4

  model.progressVisible(true)
  document.body.innerHTML = ""
  document.body.appendChild(Template3(model))

  messageIndex = 0
  model.statusMessage messages.wrap(messageIndex)

  cleanup = ->
    clearInterval i1
    clearInterval i2

  url = "http://#{model.domain()}.whimsy.space"
  detect = ->
    $.get url 
    .done (r) ->
      cleanup()
      show4()
    .fail (e) ->
      console.log e

  detect()

  i1 = setInterval ->
    messageIndex += 1
    model.statusMessage messages.wrap(messageIndex)
    
    detect()
    
  , 60000
  
  i2 = setInterval ->
    m = model.statusMessage()
    model.statusMessage m + "."
  , 5000

show4 = ->
  animate music, "volume", 0.5
  model.progressVisible(false)
  document.body.innerHTML = ""
  document.body.appendChild(Template4(model))
