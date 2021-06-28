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
import asyncdispatch, base64, hashes, httpclient, httpcore, strutils, tables,
       uri

type
  InfluxClientBase*[ClientType] = ref object
    httpClient: ClientType
    host*: string
    port*: int
    ssl*: bool
    database*: string
    auth: string

  InfluxClient* = InfluxClientBase[HttpClient]

  AsyncInfluxClient* = InfluxClientBase[AsyncHttpClient]

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

func `$`*(i: InfluxClient): string =
  var hostUri = initUri()
  if i.ssl:
    hostUri.scheme = "https"
  else:
    hostUri.scheme = "http"
  hostUri.hostname = i.host
  hostUri.port = $i.port
  hostUri.query = encodeQuery(@[("db", i.database)])
  $hostUri

proc newInfluxClient*(host: string, database: string, port = 8086, ssl = false,
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
  new result
  result.host = host
  result.port = port
  result.database = database
  result.ssl = ssl
  result.httpClient = newHttpClient(timeout = timeout)

proc newAsyncInfluxClient*(host: string, database: string, port = 8086,
                           ssl = false): AsyncInfluxClient =
  ## Create a new AsyncInfluxClient instance for communicating with the
  ## InfluxDB API.
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
  new result
  result.host = host
  result.port = port
  result.database = database
  result.ssl = ssl
  result.httpClient = newAsyncHttpClient()

func close*(i: InfluxClient | AsyncInfluxClient) =
  ## Close any HTTP connection used by the Influx client.
  i.httpClient.close()

func toInfluxStatus*(code: HttpCode): InfluxStatus =
  ## Get InfluxStatus from HTTP response code.
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

proc setBasicAuth*(i: InfluxClient, user: string, pwd: string) =
  ## Use Basic authentication.
  i.auth = "Basic " & encode(user & ":" & pwd)

proc setTokenAuth*(i: InfluxClient, token: string) =
  ## Use Token authentication.
  i.auth = "Token " & token

proc addTag*(l: DataPoint, name: string, value: string) =
  ## Add a measurement tag.
  l.tags[name] = "\"" & value & "\""

proc addField*(l: DataPoint, name: string, value: string) =
  ## Add a measurement field.
  l.fields[name] = "\"" & value & "\""

proc addField*(l: DataPoint, name: string, value: int) =
  l.fields[name] = $value & "i"

proc addField*(l: DataPoint, name: string, value: float) =
  l.fields[name] = $value

proc addField*(l: DataPoint, name: string, value: bool) =
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

proc request*(i: InfluxClient | AsyncInfluxClient, endpoint: string,
              httpMethod = HttpGet, data = "",
              queryString: seq[(string, string)] = @[]):
              Future[Response | AsyncResponse] {.multisync.} =
  ## Send request to Influx using connection values from `client` directed
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
  i.httpClient.headers = newHttpHeaders()
  if i.auth != "":
    i.httpClient.headers["Authorization"] = i.auth
  return await i.httpClient.request($hostUri, httpMethod, data)

proc ping*(i: InfluxClient | AsyncInfluxClient):
           Future[Response | AsyncResponse] {.multisync.} =
  ## Ping InfluxDB to check instance status.
  return await i.request("/ping", HttpGet)

proc query*(i: InfluxClient | AsyncInfluxClient, q: string, database = "",
            chunked = false, chunkSize = 10000, epoch = "ns", pretty = false):
            Future[Response | AsyncResponse] {.multisync.} =
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
  return await i.request("/query", meth, queryString = querySeq)

proc write*(i: InfluxClient | AsyncInfluxClient, data: string,
            database: string = ""): Future[Response | AsyncResponse]
            {.multisync.} =
  ## Write data points to InfluxDB using Line Protocol.
  var db: string
  if database != "":
    db = database
  elif i.database != "":
    db = i.database
  return await i.request("/write", HttpPost, data, @[("db", db)])

proc write*(i: InfluxClient | AsyncInfluxClient, data: seq[DataPoint],
            database = ""): Future[Response | AsyncResponse] {.multisync.} =
  return await i.write(data.join("\n"), database)

proc write*(i: InfluxClient | AsyncInfluxClient, data: DataPoint,
            database = ""): Future[Response | AsyncResponse] {.multisync.} =
  return await i.write($data, database)
