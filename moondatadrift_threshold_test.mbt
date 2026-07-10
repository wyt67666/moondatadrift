test "stable verdict for identical tables" {
  let report = @moondatadrift.analyze_tables(
    ["x"],
    [["1"], ["2"], ["3"]],
    ["x"],
    [["1"], ["2"], ["3"]],
  )
  inspect(report.contains("verdict: stable"), content="true")
}

test "drift verdict for shifted categorical values" {
  let report = @moondatadrift.analyze_tables(
    ["x"],
    [["a"], ["a"], ["a"], ["a"]],
    ["x"],
    [["b"], ["b"], ["b"], ["b"]],
  )
  inspect(report.contains("verdict: drift"), content="true")
}
