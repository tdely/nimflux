import asyncdispatch, httpclient, unittest

import nimflux

suite "InfluxClient":
  var client = newInfluxClient("localhost", "nimtest")

  test "ping":
    var resp = client.ping()
    check resp.code == Http204
    check resp.code.toInfluxStatus == InfluxStatus.Ok

  test "write incorrect":
    var resp = client.write("lorem ipsum")
    check resp.code == Http400
    check resp.code.toInfluxStatus == BadRequest

  test "write string":
    var resp = client.write("tm tf=1i")
    check resp.code == Http204
    check resp.code.toInfluxStatus == InfluxStatus.Ok

  test "write DataPoint":
    var d = DataPoint(measurement: "tm")
    d.addField("tf", 1)
    var resp = client.write(d)
    check resp.code == Http204
    check resp.code.toInfluxStatus == InfluxStatus.Ok

  test "write seq[DataPoint]":
    var d1 = DataPoint(measurement: "tm")
    var d2 = DataPoint(measurement: "tm")
    d1.addField("tf", 1)
    d2.addField("tf", 2)
    var resp = client.write(@[d1, d2])
    check resp.code == Http204
    check resp.code.toInfluxStatus == InfluxStatus.Ok

  test "query incorrect":
    var resp = client.query("")
    check resp.code == Http400
    check resp.code.toInfluxStatus == BadRequest

  test "query OK":
    var resp = client.query("select * from tm")
    check resp.code == Http200
    check resp.code.toInfluxStatus == InfluxStatus.Ok

suite "AsyncInfluxClient":
  var client = newAsyncInfluxClient("localhost", "nimtest")

  test "write DataPoint":
    var
      d1 = DataPoint(measurement: "tm")
    d1.addField("tf", 1)
    var future = client.write(d1)
    var resp = waitFor(future)
    check resp.code == Http204
