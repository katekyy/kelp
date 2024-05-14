import kelp/[memory, code]

{.push warning[Deprecated]: off.}
import std/[
  os, threadpool,
  locks, atomics,
  cpuinfo
]
{.pop.}

const
  RegisterCount = uint16.high.int + 1

type
  Register* = distinct ptr uint64
  Stack* = ref object
    stack: seq[seq[Register]]

  Blade* = ref object
    vm: Kelp
    stack: Stack
    scheduler: int = -1
    id, pc, timeout: int
    code: seq[Instruction]

  Scheduler* = ref object
    vm: Kelp
    id, state, limit, current: int
    queue: seq[int]

  Kelp* = ref object
    heartbeat: uint
    schedule: Lock
    unscheduled: Atomic[int]
    blades: seq[Blade]
    schedulers: seq[Scheduler]
    shouldExit: bool
    mem: MemoryManager

proc newKelp*(processLimitPerScheduler: int = 255): Kelp =
  result = new Kelp
  result.mem = newMemoryManager()
  result.schedulers = newSeq[Scheduler]( countProcessors() )
  result.schedule.initLock
  for idx, _ in result.schedulers:
    result.schedulers[idx] = Scheduler(
      vm: result,
      id: idx,
      limit: processLimitPerScheduler
    )

proc newRegister*(): Register =
  result = cast[Register]( allocShared0(uint64.sizeof) )

proc store*(reg: Register, x: uint64) =
  cast[ptr uint64](reg)[] = x

proc load*(reg: Register): uint64 =
  result = cast[ptr uint64](reg)[]

proc initRegisters*(regs: var seq[Register]) =
  regs = newSeq[Register](RegisterCount)
  for idx, _ in regs:
    regs[idx] = newRegister()

proc newStack*(): Stack =
  result = Stack(stack: newSeq[seq[Register]](1))
  result.stack[0].initRegisters

proc reg*(self: Stack, reg: SomeInteger): Register =
  result = self.stack[self.stack.high][reg]

proc push*(self: Stack) =
  self.stack.add newSeq[Register]()
  self.stack[self.stack.high].initRegisters

proc pop*(self: Stack) =
  discard self.stack.pop

proc newBlade*(self: Kelp, code: seq[uint8]): int =
  self.schedule.withLock:
    result = self.blades.len
    self.blades.add Blade(
      vm: self,
      id: result,
      code: parseCode(code),
      stack: newStack()
    )
    atomicInc self.unscheduled

proc layout(i: Instruction, match: openArray[OpKind]): bool =
  if match.len != i.ops.len: return false
  result = true
  for idx, op in i.ops:
    if op.kind != match[idx]: return false

proc eval(self: Scheduler, blade: Blade) =
  if blade.pc >= blade.code.len: return
  let
    i = blade.code[blade.pc]
    bladeIntoScope = blade

  proc reg(reg: SomeInteger): Register =
    result = bladeIntoScope.stack.reg(reg)

  case i.kind:
  of ikMove:
    if i.layout @[okRegister, okInstant]:
      reg(i.ops[0].value).store(i.ops[1].value)
    elif i.layout @[okRegister, okRegister]:
      reg(i.ops[0].value).store(reg(i.ops[1].value).load)
    else: discard # TODO

  of ikAdd:
    if i.layout @[okRegister, okInstant]:
      reg(i.ops[0].value).store(reg(i.ops[0].value).load + i.ops[1].value)
    elif i.layout @[okRegister, okRegister]:
      reg(i.ops[0].value).store(reg(i.ops[0].value).load + reg(i.ops[1].value).load)
    else: discard # TODO

  of ikSubtract:
    if i.layout @[okRegister, okInstant]:
      reg(i.ops[0].value).store(reg(i.ops[0].value).load - i.ops[1].value)
    elif i.layout @[okRegister, okRegister]:
      reg(i.ops[0].value).store(reg(i.ops[0].value).load - reg(i.ops[1].value).load)
    else: discard # TODO

  of ikCompare:
    let
      src = if i.layout @[okRegister, okInstant]:
        i.ops[1].value
      elif i.layout @[okRegister, okRegister]:
        reg(i.ops[1].value).load
      else: 0 # TODO
      dst = reg(i.ops[0].value)

    if dst.load == src:  dst.store 0b010
    elif dst.load < src: dst.store 0b001
    elif dst.load > src: dst.store 0b100
    else:                dst.store 0

  of ikJump:
    if i.layout @[okInstant]:
      blade.pc = i.ops[0].value.int
    elif i.layout @[okRegister]:
      blade.pc = reg(i.ops[0].value).load.int
    else: discard # TODO

  of ikJumpEQ:
    let newPc = if i.layout @[okRegister, okInstant]:
        i.ops[1].value.int
      elif i.layout @[okRegister, okRegister]:
        reg(i.ops[1].value).load.int
      else: 0 # TODO
    case reg(i.ops[0].value).load:
    of 0b010: blade.pc = newPc
    else: discard

  of ikJumpNE:
    let newPc = if i.layout @[okRegister, okInstant]:
        i.ops[1].value.int
      elif i.layout @[okRegister, okRegister]:
        reg(i.ops[1].value).load.int
      else: 0 # TODO
    case reg(i.ops[0].value).load:
    of 0b010: discard
    else: blade.pc = newPc

  of ikJumpGT:
    let newPc = if i.layout @[okRegister, okInstant]:
        i.ops[1].value.int
      elif i.layout @[okRegister, okRegister]:
        reg(i.ops[1].value).load.int
      else: 0 # TODO
    case reg(i.ops[0].value).load:
    of 0b001: blade.pc = newPc
    else: discard

  of ikJumpLT:
    let newPc = if i.layout @[okRegister, okInstant]:
        i.ops[1].value.int
      elif i.layout @[okRegister, okRegister]:
        reg(i.ops[1].value).load.int
      else: 0 # TODO
    case reg(i.ops[0].value).load:
    of 0b100: blade.pc = newPc
    else: discard

  of ikJumpGE:
    let newPc = if i.layout @[okRegister, okInstant]:
        i.ops[1].value.int
      elif i.layout @[okRegister, okRegister]:
        reg(i.ops[1].value).load.int
      else: 0 # TODO
    case reg(i.ops[0].value).load:
    of 0b010, 0b001: blade.pc = newPc
    else: discard

  of ikJumpLE:
    let newPc = if i.layout @[okRegister, okInstant]:
        i.ops[1].value.int
      elif i.layout @[okRegister, okRegister]:
        reg(i.ops[1].value).load.int
      else: 0 # TODO
    case reg(i.ops[0].value).load:
    of 0b010, 0b100: blade.pc = newPc
    else: discard

  of ikWait:
    if i.layout @[okInstant]:
      echo $blade.id & " (at " & $blade.scheduler & ")" & " wait for " & $i.ops[0].value
      blade.timeout = self.vm.heartbeat.int + i.ops[0].value.int
    elif i.layout @[okRegister]: discard
    else: discard

  else: echo $i.kind & " unimplemented"

proc start(self: Scheduler) {.thread.} =
  self.queue = newSeqOfCap[int](self.limit)
  while not self.vm.shouldExit:
    if self.vm.unscheduled.load > 0:
      self.vm.schedule.withLock:
        for b, blade in self.vm.blades:
          if blade.scheduler < 0 and (blade.timeout > 0 and self.vm.heartbeat.int >= blade.timeout or
            blade.timeout == 0):
            blade.timeout = 0
            blade.scheduler = self.id
            self.queue.add b
            atomicDec self.vm.unscheduled
            break
    if self.queue.len > 0:
      let current = self.vm.blades[self.queue[self.current]]
      if current.timeout > 0 and self.vm.heartbeat.int < current.timeout:
        if self.vm.schedule.tryAcquire:
          self.queue.delete self.current
          current.scheduler = -1
          atomicInc self.vm.unscheduled
          self.vm.schedule.release
      else:
        self.eval current
        inc current.pc
      if self.queue.len > 0: self.current = (self.current + 1) mod self.queue.len
    else:
      sleep 1

proc startHeartbeat*(self: Kelp) {.thread.} =
  while not self.shouldExit:
    sleep 1
    inc self.heartbeat

proc start*(self: Kelp) {.thread.} =
  echo "------"
  spawn self.startHeartbeat
  for scheduler in self.schedulers:
    spawn scheduler.start
  sync()

when isMainModule:
  echo "NOT IMPLEMENTED"
