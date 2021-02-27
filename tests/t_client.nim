import unittest
import httpclient

import nimflux

suite "InfluxClient":
  var client = newInfluxClient("localhost", "nimtest")

  test "ping":
    var (resp, status) = client.ping()
    check resp.code == Http204
    check status == InfluxStatus.Ok

  test "write incorrect":
    var (resp, status) = client.write("lorem ipsum")
    check resp.code == Http400
    check status == BadRequest

  test "write string":
    var (resp, status) = client.write("tm tf=1i")
    check resp.code == Http204
    check status == InfluxStatus.Ok

  test "write DataPoint":
    var d = DataPoint(measurement: "tm")
    d.addField("tf", 1)
    var (resp, status) = client.write(d)
    check resp.code == Http204
    check status == InfluxStatus.Ok

  test "write seq[DataPoint]":
    var d1 = DataPoint(measurement: "tm")
    var d2 = DataPoint(measurement: "tm")
    d1.addField("tf", 1)
    d2.addField("tf", 2)
    var (resp, status) = client.write(@[d1, d2])
    check resp.code == Http204
    check status == InfluxStatus.Ok

  test "query incorrect":
    var (resp, status) = client.query("")
    check resp.code == Http400
    check status == BadRequest

  test "query OK":
    var (resp, status) = client.query("select * from tm")
    check resp.code == Http200
    check status == InfluxStatus.Ok
