// Higher-kinded types are not supported in MoonBit traits, so we remove this trait definition for now.

/// State Monad 满足以下法则：
/// 1. 左单位元: pure(a).bind(f) == f(a)
/// 2. 右单位元: m.bind(pure) == m
/// 3. 结合律: m.bind(f).bind(g) == m.bind(fn(x) { f(x).bind(g) })

///|
struct State[S, V] {
  runState : (S) -> (V, S)
}

///|
pub fn[S, V] State::state(f : (S) -> (V, S)) -> State[S, V] {
  { runState: f, }
}

///|
pub fn[S, V] State::new(val : V) -> State[S, V] {
  { runState: fn(state : S) -> (V, S) { (val, state) }, }
}

///|
pub fn[S, V] State::run_state(self : State[S, V], state : S) -> (V, S) {
  (self.runState)(state)
}

///|
pub fn[S, V] State::eval_state(self : State[S, V], state : S) -> V {
  State::run_state(self, state).0
}

///|
pub fn[S, V] State::exec_state(self : State[S, V], state : S) -> S {
  State::run_state(self, state).1
}

///|
pub fn[S, V, A] State::bind(
  self : State[S, V],
  f : (V) -> State[S, A],
) -> State[S, A] {
  {
    runState: fn(state : S) {
      let (val, new_state) = (self.runState)(state)
      (f(val).runState)(new_state)
    },
  }
}

///|
// pub fn [S, V, W] State::map(self : State[S, V], f : (V) -> W) -> State[S, W] {
//   {
//     runState: fn(state : S) {
//       let (val, new_state) = (self.runState)(state)
//       (f(val), new_state)
//     },
//   }
// }
pub fn[S, V, W] State::map(self : State[S, V], f : (V) -> W) -> State[S, W] {
  self.bind(fn(val) { State::new(f(val)) })
}

///|
pub fn[S, V, W] State::apply(
  self : State[S, (V) -> W],
  arg : State[S, V],
) -> State[S, W] {
  self.bind(fn(f) { arg.map(f) })
}

///|
pub fn[S] State::modify(f : (S) -> S) -> State[S, Unit] {
  { runState: fn(state : S) { ((), f(state)) }, }
}

///|
pub fn[S] State::get() -> State[S, S] {
  { runState: fn(state : S) -> (S, S) { (state, state) }, }
}

///|
pub fn[S] State::put(new_state : S) -> State[S, Unit] {
  { runState: fn(_ : S) -> (Unit, S) { ((), new_state) }, }
}

///|
/// 将 Array[State[S, A]] 转为 State[S, Array[A]]
pub fn[S, A] State::sequence(states : Array[State[S, A]]) -> State[S, Array[A]] {
  fn fold_fn(
    acc : State[S, Array[A]],
    state : State[S, A],
  ) -> State[S, Array[A]] {
    acc.bind(fn(arr) { state.map(fn(a) { arr + [a] }) })
  }
  states.fold(init=State::new([]), fold_fn)
}

///|
/// 将 Array[A] 映射为 State[S, B] 后 sequence
pub fn[S, A, B] State::traverse(
  arr : Array[A],
  f : (A) -> State[S, B],
) -> State[S, Array[B]] {
  State::sequence(arr.map(f))
}
