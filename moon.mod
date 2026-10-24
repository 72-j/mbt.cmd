// MoonBit module manifest — mooncmd
// 定位：主仓通用 CQRS/事件溯源框架独立模块（命令 → 纯事件 → EventMessage
// 自动包装 → EventStore → 投影/快照的最小完备抽象）；架构思想档案见
// spec.md / const.md / adr.md；发布元数据变更须经发布前评审
// （moonxr/release_review.mbtx，独立 clone 真路径——workspace 成员目录
// 内跑会带上全 workspace，见脚本头注）。

name = "thy1016/mooncmd"

version = "0.1.1"

repository = "https://www.gitlink.org.cn/thy7/mbt.cmd"

license = "MulanPSL-2.0"

keywords = [
  "event-sourcing",
  "cqrs",
  "event-store",
  "aggregate",
  "snapshot",
  "sqlite",
]

description = "Command-side event sourcing kernel for MoonBit: pure command handlers, auto-wrapped EventMessage metadata (correlation/causation), optimistic concurrency with duplicate-version rejection, SQLite event store, projections and snapshots."

readme = "README.md"

preferred_target = "wasm"

import {
  "moonbitlang/async@0.22.4",
  "moonbitlang/x@0.5.5",
  "moonbit-community/sqlite3@0.2.3",
  "f4ah6o/uuidm@0.2.1",
}
