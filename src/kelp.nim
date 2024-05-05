import kelp/[
  memory,
  blade,
]

{.push warning[Deprecated]: off.}
import std/[
  os, cpuinfo, threadpool
]
{.pop.}

when isMainModule:
  import kelp/assembler
  import std/[syncio, strutils]

export
  blade

type
  BladeState* = enum
    bsReady
    bsRunning
    bsExited
    bsTrapped

  ScheduledBlade* = ref object
    priority*: int
    blade*: Blade
    state*: BladeState

  Scheduler* = ref object
    id*, ping*: int
    kelp*: Kelp
    shouldExit*: bool
    scheduledBlades*, exitedBlades*: seq[int]
    currentBlade*, currentBladeTicks*: int

  Kelp* = ref object
    started*: bool
    blades*: seq[ScheduledBlade]
    schedulers*: seq[Scheduler]
    latestScheduler*: int
    mem*: MemoryManager


proc newScheduler(kelp: Kelp, id: int): Scheduler =
  result = new Scheduler
  result.kelp = kelp
  result.id = id

proc newKelp*(): Kelp =
  result = new Kelp
  result.mem = newMemoryManager()
  result.schedulers = newSeq[Scheduler]( countProcessors() )
  for id in 0..result.schedulers.high:
    result.schedulers[id] = newScheduler(result, id)

proc getCurrentBlade(self: Scheduler): ScheduledBlade =
  result = self.kelp.blades[self.scheduledBlades[self.currentBlade]]

proc switchBlade(self: Scheduler): bool =
  if self.scheduledBlades.len == 0:
    return true
  if self.currentBladeTicks > 0:
    dec self.currentBladeTicks
    return
  self.currentBlade = (self.currentBlade + 1) mod self.scheduledBlades.len
  if self.getCurrentBlade.state == bsExited:
    return true
  self.currentBladeTicks = self.getCurrentBlade.priority

proc start(self: Scheduler) {.thread.} =
  while not self.kelp.started: sleep 1
  while not self.shouldExit:
    self.ping = (self.ping + 1) mod int.high

    if self.switchBlade:
      sleep 1
      continue

    var vmopt: int
    try:
      vmopt = self.getCurrentBlade.blade.step()
    except Exception as e:
      echo "blade " & $self.getCurrentBlade.blade & " got trapped: " & e.msg
      self.getCurrentBlade.state = bsTrapped
      self.scheduledBlades.delete self.currentBlade
      self.exitedBlades.add self.currentBlade

    case vmopt:
    of 1:
      self.getCurrentBlade.state = bsExited
      self.exitedBlades.add self.currentBlade
    else: discard

proc scheduleBlade(self: Scheduler, pid: int) =
  if self.exitedBlades.len > 0:
    self.scheduledBlades[self.exitedBlades.pop] = pid
  else:
    self.scheduledBlades.add pid
  spawn self.start

proc scheduleNewBlade*(self: Kelp, code: seq[uint8], priority: range[0..255] = 0): int =
  let blade = ScheduledBlade(
    priority: priority,
    blade: newBlade(self.mem, self.blades.len, code)
  )
  self.blades.add blade
  self.schedulers[self.latestScheduler].scheduleBlade(blade.blade.pid)
  self.latestScheduler = (self.latestScheduler + 1) mod self.schedulers.len

#proc debug*(self: Kelp) {.thread.} =
#  while true:
#    echo "--------------VM DEBUG--------------"
#    for sched in self.schedulers:
#      echo "sched: " & $sched.id & "; shouldExit: " & $sched.shouldExit & "; ping: " & $sched.ping
#      echo "  thrs: " & $sched.scheduledBlades

#    echo "------------------------------------"
#    echo self.threads[0].state
#    echo "------------------------------------"
#    sleep 500

proc start*(self: Kelp) {.thread.} =
  self.started = true
  #spawn self.debug
  sync()


when isMainModule:
  let kb = assemble(open(commandLineParams().join()).readAll)

  var buf = newStringOfCap(kb.len * 3 + 3)
  buf.add "@["
  for idx, b in kb:
    buf.add b.repr
    if idx == 0:
      buf.add "'u8"
    if idx != kb.high:
      buf.add ", "
  buf.add ']'
  echo buf

  writeFile "out.kb", kb
  echo "NOT IMPLEMENTED"
