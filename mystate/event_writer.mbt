// event_writer.mbt
//! 专门用于事件累积的 Writer

///|
pub struct EventWriter[E, A] {
  run : () -> (A, Array[E])
}

///|
pub fn[E, A] EventWriter::new(run : () -> (A, Array[E])) -> EventWriter[E, A] {
  EventWriter::{ run, }
}
// impl[E, A] EventWriter[E, A] {

///|
/// 纯值
pub fn[E, A] EventWriter::pure(value : A) -> EventWriter[E, A] {
  EventWriter::new(fn() { (value, []) })
}

///|
/// 产生单个事件
pub fn[E] EventWriter::tell(event : E) -> EventWriter[E, Unit] {
  EventWriter::new(fn() { ((), [event]) })
}

///|
/// 产生多个事件
pub fn[E] EventWriter::tell_many(events : Array[E]) -> EventWriter[E, Unit] {
  EventWriter::new(fn() { ((), events) })
}

///|
/// 组合
pub fn[E, A, B] EventWriter::bind(
  self : EventWriter[E, A],
  f : (A) -> EventWriter[E, B],
) -> EventWriter[E, B] {
  EventWriter::new(fn() {
    let (val, events1) = (self.run)()
    let (new_val, events2) = (f(val).run)()
    (new_val, events1 + events2)
  })
}

///|
/// 映射
pub fn[E, A, B] EventWriter::map(
  self : EventWriter[E, A],
  f : (A) -> B,
) -> EventWriter[E, B] {
  self.bind(fn(a) { EventWriter::pure(f(a)) })
}

///|
/// 执行
pub fn[E, A] EventWriter::run_writer(self : EventWriter[E, A]) -> (A, Array[E]) {
  (self.run)()
}

///|
pub fn[E, A] EventWriter::eval(self : EventWriter[E, A]) -> A {
  (self.run)().0
}

///|
pub fn[E, A] EventWriter::exec(self : EventWriter[E, A]) -> Array[E] {
  (self.run)().1
}
// }

// 工具函数

///|
pub fn[E, A] EventWriter::sequence(
  writers : Array[EventWriter[E, A]],
) -> EventWriter[E, Array[A]] {
  let init = EventWriter::pure([])
  writers.fold(init~, fn(acc, w) {
    acc.bind(fn(arr) { w.map(fn(a) { arr + [a] }) })
  })
}

///|
pub fn[E, A, B] EventWriter::traverse(
  arr : Array[A],
  f : (A) -> EventWriter[E, B],
) -> EventWriter[E, Array[B]] {
  EventWriter::sequence(arr.map(f))
}
