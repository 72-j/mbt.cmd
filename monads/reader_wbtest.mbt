///|
test "Reader::pure/basic" {
  let r = Reader::pure(42)
  inspect(Reader::run(r, ()), content="42")
  let s = Reader::pure("hello")
  inspect(Reader::run(s, 0), content="hello")
}

///|
test "Reader::bind/composition" {
  let r = Reader::pure(10)
  let f = fn(x : Int32) { Reader::pure(x * 2) }
  let g = fn(x : Int32) { Reader::pure(x + 1) }
  let r1 = Reader::bind(r, f)
  let r2 = Reader::bind(r1, g)
  inspect(Reader::run(r2, ()), content="21")
}

///|
test "Reader::ask/environment_access" {
  let get_length = Reader::asks(fn(s : String) { s.length() })
  inspect(Reader::run(get_length, "hello"), content="5")
  inspect(Reader::run(get_length, ""), content="0")
}
