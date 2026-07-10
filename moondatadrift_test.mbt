///|
test "demo report includes numeric and categorical drift" {
  let report = @moondatadrift.analyze_demo()
  inspect(report.contains("MoonDataDrift report"), content="true")
  inspect(report.contains("age (numeric)"), content="true")
  inspect(report.contains("device (categorical)"), content="true")
  inspect(report.contains("PSI"), content="true")
  inspect(report.contains("KS-like"), content="true")
}
