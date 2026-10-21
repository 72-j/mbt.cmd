// writer.mbt
//! Writer Monad - 用于累积日志/事件

/// Writer Monad 类型
// pub struct Writer[W, A] {
//   run : () -> (A, W)
// }

///|
/// Writer Monad 类型
pub struct Writer[W, A] {
  run : () -> (A, W)
  config : WriterConfig[W]
}

///|
pub struct WriterConfig[W] {
  empty : W
  concat : (W, W) -> W
}
/// Builder 模式
// pub struct WriterBuilder[W, A] {
//   empty : W
//   concat : (W, W) -> W
//   value : Option[A]
//   log : Option[W]
// }

///|
pub fn[W] Writer::new(empty : W, concat : (W, W) -> W) -> WriterConfig[W] {
  WriterConfig::{ empty, concat, }
}

///|
pub fn[W, A] Writer::pure(value : A, config : WriterConfig[W]) -> Writer[W, A] {
  { run: fn() { (value, config.empty) }, config, }
}

///|
/// 产生日志
pub fn[W] Writer::tell(log : W, config : WriterConfig[W]) -> Writer[W, Unit] {
  { run: fn() { ((), log) }, config, }
}

///|
/// 组合
pub fn[W, A, B] Writer::bind(
  self : Writer[W, A],
  f : (A) -> Writer[W, B],
) -> Writer[W, B] {
  let config = self.config
  {
    run: fn() {
      let (val, log1) = (self.run)()
      let writer2 = f(val)
      let (new_val, log2) = (writer2.run)()
      (new_val, (config.concat)(log1, log2))
    },
    config,
  }
}

///|
/// 映射
pub fn[W, A, B] Writer::map(self : Writer[W, A], f : (A) -> B) -> Writer[W, B] {
  self.bind(fn(a) { Writer::pure(f(a), self.config) })
}

///|
/// 执行并获取结果和日志
pub fn[W, A] Writer::run_writer(self : Writer[W, A]) -> (A, W) {
  (self.run)()
}

///|
/// 执行并只获取值
pub fn[W, A] Writer::eval(self : Writer[W, A]) -> A {
  (self.run)().0
}

///|
/// 执行并只获取日志
pub fn[W, A] Writer::exec(self : Writer[W, A]) -> W {
  (self.run)().1
}
