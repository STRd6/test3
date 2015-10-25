require "cornerstone"
Uploader = require "s3-uploader"

log = console.log.bind(console)

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

model =
  email: Observable "duder@whimsy.space"
  domain: Observable "awesome"
  token: Observable ""
  status: Observable ""
  progressVisible: Observable false
  progress: Observable 0
  step1: (e) ->
    e.preventDefault()
    register(@email(), @domain())
  step2: (e) ->
    e.preventDefault()
    publish(@token())

Template = require "./template"
Template2 = require "./template2"
document.body.appendChild(Template(model))

register = (email, domain) ->
  model.progressVisible(true)

  $.post "http://api.whimsy.space/register",
    email: email
    domain: domain
  .done (data, status, xhr) ->
    document.body.innerHTML = ""
    document.body.appendChild(Template2(model))

  .fail (xhr, status) ->
    console.log 'fail', arguments
  .always ->
    model.progressVisible(false)

publish = (token) ->
  fetchPolicy(token)
  .then (policy) ->
    # Save index page
    postmaster.invokeRemote "system", "exec", "return system.PACKAGE"
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
    postmaster.invokeRemote "system", "exec", "return system.filesystem().I.files"
    .then (fs) ->
      console.log fs
      fsBlob = new Blob [JSON.stringify(files: fs)], type: "application/json"
      saveBlob(policy, "index.json", fsBlob)
      .then log
