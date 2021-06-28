Nimflux
=======

InfluxDB API client library for Nim.

Nimflux provides the InfluxClient type for communicating with the InfluxDB API.
InfluxClient can be used to `ping`, `write`, `query`, or send a custom `request`.
The DataPoint type is used to create measurements for `write`, although it is
also possible use your own Line Protocol string.

```nim
import nimflux

var data = DataPoint(measurement: "temp")
data.addTag("loc", "home")
data.addField("ambient", 22.0)

var client = newInfluxClient("localhost", "nimtest")
var resp = client.write(data)
assert resp.code.toInfluxStatus == Ok
resp = client.query("select * from temp")
echo resp.body
```

It also supports asynchronously actions through `AsyncInfluxClient`:

```nim
import asyncdispatch, nimflux

var data = DataPoint(measurement: "temp")
data.addTag("loc", "home")
data.addField("ambient", 22.0)

proc asyncProc(data: DataPoint): Future[AsyncResponse] {.async.} =
  var client = newAsyncInfluxClient("localhost", "nimtest")
  var resp = await client.write(data)
  assert resp.code.toInfluxStatus == Ok
  return await client.query("select * from temp")

echo asyncProc(data).waitFor().body.waitFor()
```
