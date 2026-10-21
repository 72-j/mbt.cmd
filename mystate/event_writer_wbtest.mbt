///|
test "EventWriter basic" {
  let writer = EventWriter::tell(1)
    .bind(fn(_) { EventWriter::tell(2) })
    .bind(fn(_) { EventWriter::tell(3) })

  let (_, events) = writer.run_writer()
  assert_eq(events, [1, 2, 3])
}

///|
test "EventWriter map" {
  let writer = EventWriter::tell(42).map(fn(_) { "done" })

  let (value, events) = writer.run_writer()
  assert_eq(value, "done")
  assert_eq(events, [42])
}

///|
test "EventWriter sequence" {
  let writers = [
    EventWriter::tell(1),
    EventWriter::tell(2),
    EventWriter::tell(3),
  ]

  let program = EventWriter::sequence(writers)
  let (_, events) = program.run_writer()
  assert_eq(events, [1, 2, 3])
}

///|
test "EventWriter traverse" {
  let numbers = ["10", "20", "30"]

  let program = EventWriter::traverse(numbers, fn(n) { EventWriter::tell(n) })

  let (_, events) = program.run_writer()
  assert_eq(events, ["10", "20", "30"])
}
