///|
test "State Test - basic new and run" {
  let state = State::new(42)
  let (result, final_state) = State::run_state(state, 10)

  inspect(result, content="42")
  inspect(final_state, content="10")
}

///|
test "State Test - bind composition" {
  let increment = State::state(fn(s : Int32) { ((), s + 1) })
  let double = State::state(fn(s : Int32) { ((), s * 2) })

  let combined = increment.bind(fn(_) { double })

  let (result, final_state) = State::run_state(combined, 3)

  inspect(result, content="()")
  inspect(final_state, content="8")
}

///|
test "State Test - eval_state and exec_state" {
  let state = State::state(fn(s : Int32) { (s * 2, s + 10) })

  let value = State::eval_state(state, 5)
  let final_s = State::exec_state(state, 5)

  inspect(value, content="10")
  inspect(final_s, content="15")
}

///|
test "State Test - map" {
  let state = State::state(fn(s : Int32) { (s * 2, s + 1) })
  let mapped = state.map(fn(v) { v + 10 })

  let (result, final_state) = State::run_state(mapped, 5)

  inspect(result, content="20")
  inspect(final_state, content="6")
}

///|
test "State Test - apply" {
  let func_state = State::state(fn(s : Int32) { (fn(x : Int32) { x + 10 }, s) })
  let arg_state = State::state(fn(s : Int32) { (5, s + 1) })

  let applied = State::apply(func_state, arg_state)
  let (result, final_state) = State::run_state(applied, 0)

  inspect(result, content="15")
  inspect(final_state, content="1")
}

///|
test "State Test - get" {
  let get_state = State::get()
  let (result, final_state) = State::run_state(get_state, 42)

  inspect(result, content="42")
  inspect(final_state, content="42")
}

///|
test "State Test - put" {
  let put_state = State::put(100)
  let (result, final_state) = State::run_state(put_state, 42)

  inspect(result, content="()")
  inspect(final_state, content="100")
}

///|
test "State Test - modify" {
  let modify_state = State::modify(fn(s) { s * 2 })
  let (result, final_state) = State::run_state(modify_state, 21)

  inspect(result, content="()")
  inspect(final_state, content="42")
}

///|
test "State Test - sequence" {
  let states = [
    State::state(fn(s : Int32) { (s + 1, s + 1) }),
    State::state(fn(s : Int32) { (s + 2, s + 2) }),
    State::state(fn(s : Int32) { (s + 3, s + 3) }),
  ]

  let sequenced = State::sequence(states)
  let (result, final_state) = State::run_state(sequenced, 0)

  assert_eq(result, [1, 3, 6])
  inspect(final_state, content="6")
}

///|
test "State Test - traverse" {
  let arr = [1, 2, 3]
  let traversed = State::traverse(arr, fn(x) {
    State::state(fn(s : Int32) { (x * 2, s + x) })
  })

  let (result, final_state) = State::run_state(traversed, 0)

  assert_eq(result, [2, 4, 6])
  inspect(final_state, content="6")
}

///|
test "State Test - monad left identity law" {
  let a = 42
  let f = fn(x : Int32) { State::state(fn(s : Int32) { (x + 10, s + 1) }) }

  let left = State::new(a).bind(f)
  let right = f(a)

  let (left_result, left_state) = State::run_state(left, 0)
  let (right_result, right_state) = State::run_state(right, 0)

  inspect(left_result, content="52")
  inspect(right_result, content="52")
  inspect(left_state, content="1")
  inspect(right_state, content="1")
}

///|
test "State Test - monad right identity law" {
  let m = State::state(fn(s : Int32) { (s * 2, s + 5) })

  let left = m.bind(fn(x) { State::new(x) })
  let right = m

  let (left_result, left_state) = State::run_state(left, 10)
  let (right_result, right_state) = State::run_state(right, 10)

  inspect(left_result, content="20")
  inspect(right_result, content="20")
  inspect(left_state, content="15")
  inspect(right_state, content="15")
}

///|
test "State Test - monad associativity law" {
  let m = State::state(fn(s : Int32) { (s + 1, s * 2) })
  let f = fn(x : Int32) { State::state(fn(s : Int32) { (x + 10, s + 5) }) }
  let g = fn(y : Int32) { State::state(fn(s : Int32) { (y * 2, s + 3) }) }

  let left = m.bind(f).bind(g)
  let right = m.bind(fn(x) { f(x).bind(g) })

  let (left_result, left_state) = State::run_state(left, 7)
  let (right_result, right_state) = State::run_state(right, 7)

  inspect(left_result, content="36")
  inspect(right_result, content="36")
  inspect(left_state, content="22")
  inspect(right_state, content="22")
}

///|
test "State Test - complex pipeline" {
  let pipeline = State::get()
    .bind(fn(s) { State::modify(fn(_) { s * 2 }) })
    .bind(fn(_) { State::get() })
    .map(fn(s) { s + 10 })

  let (result, final_state) = State::run_state(pipeline, 5)

  inspect(result, content="20")
  inspect(final_state, content="10")
}
