///|
fn main {
  println("MoonDataDrift")
  println("Project ID: moondatadrift")
  println(
    "A MoonBit drift detector for comparing baseline and current tabular data.",
  )
  println("GitHub: https://github.com/wyt67666/moondatadrift")
  println("Sample data: data/baseline.csv vs data/current.csv")
  println("")
  println(@moondatadrift.analyze_demo())
}
