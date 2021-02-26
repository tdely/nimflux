import unittest
import tables

import coverage

import nimflux

suite "DataPoint":

  test "addField string":
    let point = DataPoint()
    point.addField("fieldStr", "hello!")
    check point.fields.hasKey("fieldStr") == true
    check point.fields["fieldStr"] == "\"hello!\""

  test "addField int":
    let point = DataPoint()
    point.addField("fieldInt", 3)
    check point.fields.hasKey("fieldInt") == true
    check point.fields["fieldInt"] == "3i"

  test "addField float":
    let point = DataPoint()
    point.addField("fieldFloat", 1.0)
    check point.fields.hasKey("fieldFloat") == true
    check point.fields["fieldFloat"] == "1.0"

  test "addField bool":
    let point = DataPoint()
    point.addField("fieldTrue", true)
    point.addField("fieldFalse", false)
    check point.fields.hasKey("fieldTrue") == true
    check point.fields.hasKey("fieldFalse") == true
    check point.fields["fieldTrue"] == "t"
    check point.fields["fieldFalse"] == "f"

  test "`$` full":
    let point = DataPoint(measurement: "msr", tags: {"tag": "tval"}.toTable, timestamp: 1)
    point.addField("field", "fval")
    check $point == "msr,tag=tval field=\"fval\" 1"

  test "`$` sans tags":
    let point = DataPoint(measurement: "msr", timestamp: 1)
    point.addField("field", "fval")
    check $point == "msr field=\"fval\" 1"

  test "`$` sans timestamp":
    let point = DataPoint(measurement: "msr", tags: {"tag": "tval"}.toTable)
    point.addField("field", "fval")
    check $point == "msr,tag=tval field=\"fval\""

echo "Coverage by file: "
for fname, num in coveragePercentageByFile().pairs():
  echo fname, " ", num

echo "Total coverage: ", totalCoverage()
