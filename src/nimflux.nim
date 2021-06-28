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
import asyncdispatch, base64, hashes, httpclient, httpcore, net, strutils,
       tables, uri

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

proc newInfluxClient*(host: string, database: string, port = 8086,
                      ssl: SslContext | bool = false, timeout = -1):
                      InfluxClient =
  ## Create a new InfluxClient instance for communicating with the InfluxDB API.
  ##
  ## ``host`` specifies the host to target.
  ##
  ## ``database`` specifies the default InfluxDB database to target.
  ##
  ## ``port`` specifies the port to target.
  ##
  ## ``ssl`` specifies the use of HTTPS communication. If value is a SslContext
  ## then that will be used in any HTTPS connection.
  ##
  ## ``timeout`` specifies the number of milliseconds to allow before a
  ## ``TimeoutError`` is raised.
  new result
  result.host = host
  result.port = port
  result.database = database
  when ssl is bool:
    result.ssl = ssl
    result.httpClient = newHttpClient(timeout = timeout)
  else:
    result.ssl = true
    result.httpClient = newHttpClient(timeout = timeout, sslContext = ssl)

proc newAsyncInfluxClient*(host: string, database: string, port = 8086,
                           ssl: SslContext | bool = false): AsyncInfluxClient =
  ## Create a new AsyncInfluxClient instance for communicating with the
  ## InfluxDB API.
  ##
  ## ``host`` specifies the host to target.
  ##
  ## ``database`` specifies the default InfluxDB database to target.
  ##
  ## ``port`` specifies the port to target.
  ##
  ## ``ssl`` specifies the use of HTTPS communication. If value is a SslContext
  ## then that will be used in any HTTPS connection.
  ##
  ## ``timeout`` specifies the number of milliseconds to allow before a
  ## ``TimeoutError`` is raised.
  new result
  result.host = host
  result.port = port
  result.database = database
  result.ssl = ssl
  when ssl is bool:
    result.ssl = ssl
    result.httpClient = newAsyncHttpClient()
  else:
    result.ssl = true
    result.httpClient = newAsyncHttpClient(sslContext = ssl)

func close*(client: InfluxClient | AsyncInfluxClient) =
  ## Close any HTTP connection used by the ``client``.
  client.httpClient.close()

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

proc setBasicAuth*(client: InfluxClient, user: string, pwd: string) =
  ## Use Basic authentication.
  client.auth = "Basic " & encode(user & ":" & pwd)

proc setTokenAuth*(client: InfluxClient, token: string) =
  ## Use Token authentication.
  client.auth = "Token " & token

proc addTag*(dp: DataPoint, name: string, value: string) =
  ## Add a measurement tag.
  dp.tags[name] = "\"" & value & "\""

proc addField*(dp: DataPoint, name: string, value: string) =
  ## Add a measurement field.
  dp.fields[name] = "\"" & value & "\""

proc addField*(dp: DataPoint, name: string, value: int) =
  dp.fields[name] = $value & "i"

proc addField*(dp: DataPoint, name: string, value: float) =
  dp.fields[name] = $value

proc addField*(dp: DataPoint, name: string, value: bool) =
  dp.fields[name] = case value:
    of true:
      "t"
    of false:
      "f"

func `$`*(dp: DataPoint): string =
  result = dp.measurement
  for key, val in dp.tags:
    result.add("," & key & "=" & val)
  result.add(" ")
  var fields = newSeq[string]()
  for key, val in dp.fields:
    fields.add(key & "=" & val)
  result.add(fields.join(","))
  if dp.timestamp != 0:
    result.add(" " & $dp.timestamp)

proc request*(client: InfluxClient | AsyncInfluxClient, endpoint: string,
              httpMethod = HttpGet, data = "",
              queryString: seq[(string, string)] = @[]):
              Future[Response | AsyncResponse] {.multisync.} =
  ## Send request to Influx using connection values from ``client`` directed
  ## at the specified InfluxDB API ``endpoint`` using the method specified by
  ## ``httpMethod``.
  var hostUri = initUri()
  if client.ssl:
    hostUri.scheme = "https"
  else:
    hostUri.scheme = "http"
  hostUri.hostname = client.host
  hostUri.port = $client.port
  hostUri.path = endpoint
  hostUri.query = encodeQuery(queryString)
  client.httpClient.headers = newHttpHeaders()
  if client.auth != "":
    client.httpClient.headers["Authorization"] = client.auth
  return await client.httpClient.request($hostUri, httpMethod, data)

proc ping*(client: InfluxClient | AsyncInfluxClient):
           Future[Response | AsyncResponse] {.multisync.} =
  ## Ping InfluxDB to check instance status.
  return await client.request("/ping", HttpGet)

proc query*(client: InfluxClient | AsyncInfluxClient, q: string, database = "",
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
  elif client.database != "":
    querySeq.add(("db", client.database))
  var mthd: HttpMethod
  if q.toLowerAscii.startsWith("select") or q.toLowerAscii.startsWith("show"):
    mthd = HttpGet
  else:
    mthd = HttpPost
  return await client.request("/query", mthd, queryString = querySeq)

proc write*(client: InfluxClient | AsyncInfluxClient, data: string,
            database: string = ""): Future[Response | AsyncResponse]
            {.multisync.} =
  ## Write data points to InfluxDB using Line Protocol.
  var db: string
  if database != "":
    db = database
  elif client.database != "":
    db = client.database
  return await client.request("/write", HttpPost, data, @[("db", db)])

proc write*(client: InfluxClient | AsyncInfluxClient, data: seq[DataPoint],
            database = ""): Future[Response | AsyncResponse] {.multisync.} =
  return await client.write(data.join("\n"), database)

proc write*(client: InfluxClient | AsyncInfluxClient, data: DataPoint,
            database = ""): Future[Response | AsyncResponse] {.multisync.} =
  return await client.write($data, database)
