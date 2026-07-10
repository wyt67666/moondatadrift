///|
pub struct Table {
  headers : Array[String]
  rows : Array[Array[String]]
}

///|
priv struct ColumnReport {
  name : String
  kind : String
  baseline_missing_ratio : Double
  current_missing_ratio : Double
  missing_delta_pp : Double
  baseline_quantiles : Array[Double]
  current_quantiles : Array[Double]
  psi : Double
  ks_like : Double
  drift_score : Double
  summary : String
}

///|
priv struct DriftReport {
  title : String
  baseline_name : String
  current_name : String
  baseline_rows : Int
  current_rows : Int
  columns : Array[ColumnReport]
  notes : Array[String]
}

///|
fn build_table(headers : Array[String], rows : Array[Array[String]]) -> Table {
  { headers, rows }
}

///|
fn analyze_pair(
  baseline : Table,
  current : Table,
  baseline_name : String,
  current_name : String,
) -> DriftReport {
  let shared_columns = min_int(
    baseline.headers.length(),
    current.headers.length(),
  )
  let reports : Array[ColumnReport] = []
  for i in 0..<shared_columns {
    reports.push(
      analyze_column(
        baseline.headers[i],
        table_column(baseline, i),
        table_column(current, i),
      ),
    )
  }
  let notes : Array[String] = []
  if baseline.headers.length() != current.headers.length() {
    notes.push(
      "Schema width differs: baseline has \{baseline.headers.length()} columns while current has \{current.headers.length()} columns.",
    )
  }
  if baseline.headers.length() > shared_columns {
    notes.push(
      "Baseline has \{baseline.headers.length() - shared_columns} extra column(s) that were not analyzed.",
    )
  }
  if current.headers.length() > shared_columns {
    notes.push(
      "Current has \{current.headers.length() - shared_columns} extra column(s) that were not analyzed.",
    )
  }
  {
    title: "MoonDataDrift report",
    baseline_name,
    current_name,
    baseline_rows: baseline.rows.length(),
    current_rows: current.rows.length(),
    columns: reports,
    notes,
  }
}

///|
fn analyze_pair_markdown(
  baseline : Table,
  current : Table,
  baseline_name : String,
  current_name : String,
) -> String {
  render_report(analyze_pair(baseline, current, baseline_name, current_name))
}

///|
pub fn analyze_demo() -> String {
  let baseline = demo_baseline()
  let current = demo_current()
  analyze_pair_markdown(baseline, current, "baseline.csv", "current.csv")
}

///|
pub fn analyze_tables(
  baseline_headers : Array[String],
  baseline_rows : Array[Array[String]],
  current_headers : Array[String],
  current_rows : Array[Array[String]],
) -> String {
  analyze_pair_markdown(
    build_table(baseline_headers, baseline_rows),
    build_table(current_headers, current_rows),
    "baseline.csv",
    "current.csv",
  )
}

///|
fn analyze_column(
  name : String,
  baseline : Array[String],
  current : Array[String],
) -> ColumnReport {
  let baseline_missing = missing_ratio(baseline)
  let current_missing = missing_ratio(current)
  let baseline_numeric = numeric_values(baseline)
  let current_numeric = numeric_values(current)
  let baseline_numeric_ratio = ratio(
    baseline_numeric.length(),
    count_present(baseline),
  )
  let current_numeric_ratio = ratio(
    current_numeric.length(),
    count_present(current),
  )
  let is_numeric = baseline_numeric_ratio >= 0.8 && current_numeric_ratio >= 0.8
  if is_numeric {
    let baseline_sorted = sorted_copy(baseline_numeric)
    let current_sorted = sorted_copy(current_numeric)
    let baseline_quantiles = quantile_summary(baseline_sorted)
    let current_quantiles = quantile_summary(current_sorted)
    let psi = psi_for_numeric(baseline_sorted, current_sorted)
    let ks_like = ks_like_for_numeric(baseline_sorted, current_sorted)
    let drift_score = abs_diff(baseline_missing, current_missing) +
      psi +
      ks_like
    {
      name,
      kind: "numeric",
      baseline_missing_ratio: baseline_missing,
      current_missing_ratio: current_missing,
      missing_delta_pp: (current_missing - baseline_missing) * 100.0,
      baseline_quantiles,
      current_quantiles,
      psi,
      ks_like,
      drift_score,
      summary: numeric_summary(drift_score),
    }
  } else {
    let psi = psi_for_categories(baseline, current)
    let ks_like = category_shift_like(baseline, current)
    let drift_score = abs_diff(baseline_missing, current_missing) +
      psi +
      ks_like
    let top_base = top_category(baseline)
    let top_current = top_category(current)
    {
      name,
      kind: "categorical",
      baseline_missing_ratio: baseline_missing,
      current_missing_ratio: current_missing,
      missing_delta_pp: (current_missing - baseline_missing) * 100.0,
      baseline_quantiles: [],
      current_quantiles: [],
      psi,
      ks_like,
      drift_score,
      summary: categorical_summary(top_base, top_current, drift_score),
    }
  }
}

///|
fn render_report(report : DriftReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string("# ")
  builder.write_string(report.title)
  builder.write_string("\n\n")
  builder.write_string("Baseline: ")
  builder.write_string(report.baseline_name)
  builder.write_string("\nCurrent: ")
  builder.write_string(report.current_name)
  builder.write_string("\nRows: ")
  builder.write_object(report.baseline_rows)
  builder.write_string(" vs ")
  builder.write_object(report.current_rows)
  builder.write_string("\n\n")
  if report.notes.length() > 0 {
    builder.write_string("## Notes\n")
    for note in report.notes {
      builder.write_string("- ")
      builder.write_string(note)
      builder.write_string("\n")
    }
    builder.write_string("\n")
  }
  builder.write_string("## Columns\n")
  for column in report.columns {
    builder.write_string("\n### ")
    builder.write_string(column.name)
    builder.write_string(" (")
    builder.write_string(column.kind)
    builder.write_string(")\n")
    builder.write_string("- missing ratio: ")
    builder.write_string(percent(column.baseline_missing_ratio))
    builder.write_string(" -> ")
    builder.write_string(percent(column.current_missing_ratio))
    builder.write_string(" (")
    builder.write_string(percent(column.missing_delta_pp / 100.0))
    builder.write_string(")\n")
    if column.kind == "numeric" {
      builder.write_string("- p10 / p50 / p90: ")
      write_quantile_triplet(builder, column.baseline_quantiles)
      builder.write_string(" -> ")
      write_quantile_triplet(builder, column.current_quantiles)
      builder.write_string("\n")
    }
    builder.write_string("- PSI: ")
    builder.write_string(format_float(column.psi))
    builder.write_string("\n")
    builder.write_string("- KS-like: ")
    builder.write_string(format_float(column.ks_like))
    builder.write_string("\n")
    builder.write_string("- drift score: ")
    builder.write_string(format_float(column.drift_score))
    builder.write_string("\n")
    builder.write_string(column.summary)
    builder.write_string("\n")
  }
  builder.to_string()
}

///|
fn numeric_summary(drift_score : Double) -> String {
  let verdict = drift_verdict(drift_score)
  let builder = StringBuilder::new()
  builder.write_string("- verdict: ")
  builder.write_string(verdict)
  builder.write_string("\n")
  builder.to_string()
}

///|
fn categorical_summary(
  top_base : String,
  top_current : String,
  drift_score : Double,
) -> String {
  let verdict = drift_verdict(drift_score)
  let builder = StringBuilder::new()
  builder.write_string("- top category: ")
  builder.write_string(top_base)
  builder.write_string(" -> ")
  builder.write_string(top_current)
  builder.write_string("\n")
  builder.write_string("- verdict: ")
  builder.write_string(verdict)
  builder.write_string("\n")
  builder.to_string()
}

///|
fn table_column(table : Table, index : Int) -> Array[String] {
  let values : Array[String] = []
  for row in table.rows {
    values.push(row[index])
  }
  values
}

///|
fn count_present(values : Array[String]) -> Int {
  let mut count = 0
  for value in values {
    if !is_missing(value) {
      count += 1
    }
  }
  count
}

///|
fn missing_ratio(values : Array[String]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  Double::from_int(count_missing(values)) / Double::from_int(values.length())
}

///|
fn ratio(numerator : Int, denominator : Int) -> Double {
  if denominator == 0 {
    0.0
  } else {
    Double::from_int(numerator) / Double::from_int(denominator)
  }
}

///|
fn count_missing(values : Array[String]) -> Int {
  let mut count = 0
  for value in values {
    if is_missing(value) {
      count += 1
    }
  }
  count
}

///|
fn is_missing(value : String) -> Bool {
  value == "" || value == "NA" || value == "null" || value == "None"
}

///|
fn is_numeric(value : String) -> Bool {
  if is_missing(value) {
    false
  } else {
    let _ = @string.parse_double(value) catch { _ => return false }
    true
  }
}

///|
fn numeric_values(values : Array[String]) -> Array[Double] {
  let output : Array[Double] = []
  for value in values {
    if is_numeric(value) {
      output.push(@string.parse_double(value) catch { _ => 0.0 })
    }
  }
  output
}

///|
fn sorted_copy(values : Array[Double]) -> Array[Double] {
  let output = values.copy()
  output.sort_by(fn(a, b) { if a < b { -1 } else if a > b { 1 } else { 0 } })
  output
}

///|
fn quantile_summary(values : Array[Double]) -> Array[Double] {
  if values.length() == 0 {
    []
  } else {
    [
      pick_sorted(values, 1, 10),
      pick_sorted(values, 1, 2),
      pick_sorted(values, 9, 10),
    ]
  }
}

///|
fn pick_sorted(
  values : Array[Double],
  numerator : Int,
  denominator : Int,
) -> Double {
  if values.length() == 0 {
    0.0
  } else {
    let index = (values.length() - 1) * numerator / denominator
    values[index]
  }
}

///|
fn psi_for_numeric(
  reference : Array[Double],
  current : Array[Double],
) -> Double {
  let reference_bins = bucket_counts_numeric(reference, reference)
  let current_bins = bucket_counts_numeric(reference, current)
  psi_from_bins(reference_bins, current_bins)
}

///|
fn ks_like_for_numeric(
  reference : Array[Double],
  current : Array[Double],
) -> Double {
  let reference_bins = bucket_counts_numeric(reference, reference)
  let current_bins = bucket_counts_numeric(reference, current)
  cumulative_distance(reference_bins, current_bins)
}

///|
fn bucket_counts_numeric(
  reference : Array[Double],
  sample : Array[Double],
) -> Array[Int] {
  let counts : Array[Int] = Array::make(10, 0)
  if reference.length() == 0 {
    return counts
  }
  let boundaries = [
    pick_sorted(reference, 1, 10),
    pick_sorted(reference, 2, 10),
    pick_sorted(reference, 3, 10),
    pick_sorted(reference, 4, 10),
    pick_sorted(reference, 5, 10),
    pick_sorted(reference, 6, 10),
    pick_sorted(reference, 7, 10),
    pick_sorted(reference, 8, 10),
    pick_sorted(reference, 9, 10),
  ]
  for value in sample {
    let mut bucket = 0
    while bucket < boundaries.length() && value > boundaries[bucket] {
      bucket += 1
    }
    counts[bucket] += 1
  }
  counts
}

///|
fn psi_for_categories(
  reference : Array[String],
  current : Array[String],
) -> Double {
  let categories = unique_union(reference, current)
  let ref_counts = category_counts(reference, categories)
  let cur_counts = category_counts(current, categories)
  psi_from_bins(ref_counts, cur_counts)
}

///|
fn category_shift_like(
  reference : Array[String],
  current : Array[String],
) -> Double {
  let categories = unique_union(reference, current)
  let ref_counts = category_counts(reference, categories)
  let cur_counts = category_counts(current, categories)
  cumulative_distance(ref_counts, cur_counts)
}

///|
fn unique_union(left : Array[String], right : Array[String]) -> Array[String] {
  let output : Array[String] = []
  for value in left {
    if !is_missing(value) && !array_contains(output, value) {
      output.push(value)
    }
  }
  for value in right {
    if !is_missing(value) && !array_contains(output, value) {
      output.push(value)
    }
  }
  output
}

///|
fn category_counts(
  values : Array[String],
  categories : Array[String],
) -> Array[Int] {
  let counts : Array[Int] = Array::make(categories.length(), 0)
  for value in values {
    if is_missing(value) {
      continue
    }
    let mut index = 0
    while index < categories.length() && categories[index] != value {
      index += 1
    }
    if index < categories.length() {
      counts[index] += 1
    }
  }
  counts
}

///|
fn psi_from_bins(
  reference_bins : Array[Int],
  current_bins : Array[Int],
) -> Double {
  let ref_total = sum_ints(reference_bins)
  let cur_total = sum_ints(current_bins)
  if ref_total == 0 || cur_total == 0 {
    return 0.0
  }
  let mut psi = 0.0
  for i in 0..<reference_bins.length() {
    let p = Double::from_int(reference_bins[i]) / Double::from_int(ref_total)
    let q = Double::from_int(current_bins[i]) / Double::from_int(cur_total)
    if p > 0.0 && q > 0.0 {
      psi += (p - q) * @math.ln(p / q)
    }
  }
  psi
}

///|
fn cumulative_distance(
  reference_bins : Array[Int],
  current_bins : Array[Int],
) -> Double {
  let ref_total = sum_ints(reference_bins)
  let cur_total = sum_ints(current_bins)
  if ref_total == 0 || cur_total == 0 {
    return 0.0
  }
  let mut ref_cum = 0.0
  let mut cur_cum = 0.0
  let mut max_gap = 0.0
  for i in 0..<reference_bins.length() {
    ref_cum += Double::from_int(reference_bins[i]) / Double::from_int(ref_total)
    cur_cum += Double::from_int(current_bins[i]) / Double::from_int(cur_total)
    let gap = ref_cum - cur_cum
    let abs_gap = if gap < 0.0 { -gap } else { gap }
    if abs_gap > max_gap {
      max_gap = abs_gap
    }
  }
  max_gap
}

///|
fn sum_ints(values : Array[Int]) -> Int {
  let mut total = 0
  for value in values {
    total += value
  }
  total
}

///|
fn top_category(values : Array[String]) -> String {
  let categories = unique_union(values, [])
  if categories.length() == 0 {
    return "(none)"
  }
  let counts = category_counts(values, categories)
  let mut best = 0
  let mut best_count = -1
  for i in 0..<categories.length() {
    if counts[i] > best_count {
      best = i
      best_count = counts[i]
    }
  }
  categories[best]
}

///|
fn array_contains(values : Array[String], target : String) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn percent(value : Double) -> String {
  format_float(value * 100.0) + "%"
}

///|
fn format_float(value : Double) -> String {
  let rounded = (value * 1000.0).to_int().to_double() / 1000.0
  rounded.to_string()
}

///|
fn drift_verdict(score : Double) -> String {
  if score < 0.2 {
    "stable"
  } else if score < 0.6 {
    "watch"
  } else {
    "drift"
  }
}

///|
fn write_quantile_triplet(
  builder : StringBuilder,
  quantiles : Array[Double],
) -> Unit {
  if quantiles.length() == 0 {
    builder.write_string("(n/a)")
    return
  }
  builder.write_string("[")
  builder.write_string(format_float(quantiles[0]))
  builder.write_string(", ")
  builder.write_string(format_float(quantiles[1]))
  builder.write_string(", ")
  builder.write_string(format_float(quantiles[2]))
  builder.write_string("]")
}

///|
fn min_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn abs_diff(left : Double, right : Double) -> Double {
  let gap = left - right
  if gap < 0.0 {
    -gap
  } else {
    gap
  }
}

///|
fn demo_baseline() -> Table {
  build_table(["age", "device", "amount"], [
    ["21", "mobile", "10.0"],
    ["25", "desktop", "12.0"],
    ["31", "mobile", "19.0"],
    ["43", "mobile", "24.0"],
    ["38", "desktop", "18.0"],
    ["29", "desktop", "15.0"],
    ["", "mobile", "16.0"],
    ["46", "desktop", "26.0"],
    ["52", "mobile", "28.0"],
    ["35", "desktop", "21.0"],
  ])
}

///|
fn demo_current() -> Table {
  build_table(["age", "device", "amount"], [
    ["20", "mobile", "11.0"],
    ["27", "mobile", "13.0"],
    ["33", "mobile", "19.0"],
    ["40", "tablet", "27.0"],
    ["45", "tablet", "30.0"],
    ["", "tablet", "21.0"],
    ["49", "desktop", "29.0"],
    ["55", "tablet", "33.0"],
    ["37", "mobile", "22.0"],
    ["42", "tablet", "31.0"],
  ])
}
