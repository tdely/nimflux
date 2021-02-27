# Copyright (c) 2021 Tobias Dély
#
# This software is licensed under the MIT license.
# See the file "LICENSE", included in this distribution, for details about the
# copyright.

## This module implements an InfluxDB API client.
##
## .. code-block:: Nim
##   import nimflux
##
##   var data = DataPoint(measurement: "temp")
##   data.addTag("loc", "home")
##   data.addField("ambient", 22.0)
##
##   var client = InfluxClient("localhost", "nimtest")
##   var (resp, status) = client.write(data)
##   assert status == Ok
##   (resp, status) = client.query("select * from temp")
##   echo resp.body
##

{.experimental: "strictFuncs".}
import base64, hashes, httpclient, httpcore, strutils, tables, uri

import coverage

type
  InfluxClient* = ref object
    host*: string
    port*: int
    ssl*: bool
    database*: string
    auth: string
    timeout*: int

  DataPoint* = ref object
    ## Representation of a single Influx data point.
    measurement*: string
    tags*: Table[string, string]
    fields*: Table[string, string]
    timestamp*: int64

  InfluxStatus* {.pure.} = enum
    Ok,
    BadRequest,
    Unauthorized,
    NotFound,
    RequestTooLarge,
    ServerError,
    UnknownError

func newInfluxClient*(host: string, database: string, port = 8086, ssl = false,
                      timeout = -1): InfluxClient =
  ## Create a new InfluxClient instance for communicating with the InfluxDB API.
  ##
  ## ``host`` specifies the host to target.
  ##
  ## ``database`` specifies the default InfluxDB database to target.
  ##
  ## ``port`` specifies the port to target.
  ##
  ## ``ssl`` specifies the use of HTTPS communication.
  ##
  ## ``timeout`` specifies the number of milliseconds to allow before a
  ## ``TimeoutError`` is raised.
  InfluxClient(host: host, port: port, database: database, ssl: ssl,
               timeout: timeout)

func toInfluxStatus(code: HttpCode): InfluxStatus =
  if is2xx(code):
    OK
  elif is4xx(code):
    if code == Http400:
      BadRequest
    elif code == Http401:
      Unauthorized
    elif code == Http404:
      NotFound
    elif code == Http413:
      RequestTooLarge
    else:
      UnknownError
  elif is5xx(code):
    ServerError
  else:
    UnknownError

proc setBasicAuth*(i: InfluxClient, user: string, pwd: string) {.cov.} =
  ## Use Basic authentication.
  i.auth = "Basic " & encode(user & ":" & pwd)

proc setTokenAuth*(i: InfluxClient, token: string) {.cov.} =
  ## Use Token authentication.
  i.auth = "Token " & token

proc addTag*(l: DataPoint, name: string, value: string) {.cov.} =
  ## Add a measurement tag.
  l.tags[name] = "\"" & value & "\""

proc addField*(l: DataPoint, name: string, value: string) {.cov.} =
  ## Add a measurement field.
  l.fields[name] = "\"" & value & "\""

proc addField*(l: DataPoint, name: string, value: int) {.cov.} =
  l.fields[name] = $value & "i"

proc addField*(l: DataPoint, name: string, value: float) {.cov.} =
  l.fields[name] = $value

proc addField*(l: DataPoint, name: string, value: bool) {.cov.} =
  l.fields[name] = case value:
    of true:
      "t"
    of false:
      "f"

func `$`*(l: DataPoint): string =
  result = l.measurement
  for key, val in l.tags:
    result.add("," & key & "=" & val)
  result.add(" ")
  var fields = newSeq[string]()
  for key, val in l.fields:
    fields.add(key & "=" & val)
  result.add(fields.join(","))
  if l.timestamp != 0:
    result.add(" " & $l.timestamp)

proc request*(i: InfluxClient, endpoint: string, httpMethod = HttpGet,
              data = "", queryString: seq[(string, string)] = @[]):
              (Response, InfluxStatus) {.cov.} =
  ## Send request to Influx using connection values from InfluxClient directed
  ## at the specified InfluxDB API ``endpoint`` using the method specified by
  ## ``httpMethod``.
  var hostUri = initUri()
  if i.ssl:
    hostUri.scheme = "https"
  else:
    hostUri.scheme = "http"
  hostUri.hostname = i.host
  hostUri.port = $i.port
  hostUri.path = endpoint
  hostUri.query = encodeQuery(queryString)
  let client = newHttpClient(timeout = i.timeout)
  client.headers = newHttpHeaders()
  if i.auth != "":
    client.headers["Authorization"] = i.auth
  let r = client.request($hostUri, httpMethod, data)
  (r, r.code.toInfluxStatus())

proc ping*(i: InfluxClient): (Response, InfluxStatus) =
  ## Ping InfluxDB to check instance status.
  i.request("/ping", HttpGet)

proc query*(i: InfluxClient, q: string, database = "", chunked = false,
            chunkSize = 10000, epoch = "ns", pretty = false):
            (Response, InfluxStatus) {.cov.} =
  ## Query InfluxDB using InfluxQL. HTTP method is automatically determined by
  ## the query type in ``q``.
  ##
  ## ``q`` specifies the InfluxQL query to execute.
  ##
  ## ``database`` specifies the target database. This overrides the
  ## InfluxClient setting which would otherwise be used.
  ##
  ## ``chunked`` instructs the server to return points in streamed batches
  ## (chunks) instead of in a single response.
  ##
  ## ``chunkSize`` specifies the number of points constituting a chunk.
  ##
  ## ``epoch`` specifies the precision of the timestamps returned by the query.
  ##
  ## ``pretty`` instructs the server to pretty-print returned JSON.
  var querySeq = @[("q", q),
                   ("epoch", epoch),
                   ("pretty", $pretty)]
  if chunked:
    querySeq.add(("chunked", $chunked))
  if database != "":
    querySeq.add(("db", database))
  elif i.database != "":
    querySeq.add(("db", i.database))
  var meth: HttpMethod
  if q.toLowerAscii.startsWith("select") or q.toLowerAscii.startsWith("show"):
    meth = HttpGet
  else:
    meth = HttpPost
  i.request("/query", meth, queryString = querySeq)

proc write*(i: InfluxClient, data: string, database: string = ""):
            (Response, InfluxStatus) {.cov.} =
  ## Write data points to InfluxDB using Line Protocol.
  var db: string
  if database != "":
    db = database
  elif i.database != "":
    db = i.database
  i.request("/write", HttpPost, data, @[("db", db)])

proc write*(i: InfluxClient, data: seq[DataPoint],
    database = ""): (Response, InfluxStatus) =
  i.write(data.join("\n"), database)

proc write*(i: InfluxClient, data: DataPoint, database = ""):
            (Response, InfluxStatus) =
  i.write($data, database)
