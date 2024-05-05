import ./[
  registers,
  vpointer,
  labels,
  memory,
  code
]

import std/[strutils, sequtils]

type
  Blade* = ref object
    pid*: int = -1
    pc*: int
    lem*: LabelManager
    mem*: MemoryManager
    rem*: RegisterManager
    code*: Code


proc newBlade*(mem: MemoryManager, pid: int, code: seq[uint8]): Blade =
  result = Blade(
    pid: pid,
    lem: newLabelManager(),
    mem: mem,
    rem: newRegisterManager(),
    code: parseCode code
  )

proc `$`*(b: Blade): string =
  result = "@" & $b.pid

proc heapAlloc*(self: Blade, size: int): VirtualPointer =
  result = self.mem.alloc(self.pid, size)

proc heapRealloc*(self: Blade, vp: VirtualPointer, newSize: int): VirtualPointer =
  result = self.mem.realloc(self.pid, vp, newSize)

proc heapFree*(self: Blade, vp: VirtualPointer) =
  self.mem.free(self.pid, vp)

proc heapSize*(self: Blade, vp: VirtualPointer): int =
  result = self.mem.size(self.pid, vp)

proc layout*(i: Instruction, layout: seq[OperandKind]): bool =
  if i.ops.len != layout.len: return false
  result = true
  for idx, op in layout:
    if op != i.ops[idx].kind: return false

proc compare(a: uint64, b: uint64): uint64 =
  if a == b:
    result = 0b010
  elif a > b:
    result = 0b100
  elif a < b:
    result = 0b001

proc step*(self: Blade): int =
  if self.pc == self.code.len: return 1

  var incrementPC = true
  let current = self.code[self.pc]

  case current.kind:
  of Move:
    if current.layout @[okRegister, okInstant]:
      self.rem.store(current.ops[0].register, current.ops[1].instant)
    elif current.layout @[okRegister, okRegister]:
      self.rem.store(current.ops[0].register, self.rem.peek(current.ops[1].register))
    else: discard

  of Not:
    if current.layout @[okRegister, okRegister]:
      self.rem.store(current.ops[0].register, not self.rem.peek(current.ops[1].register))
    elif current.layout @[okRegister, okInstant]:
      self.rem.store(current.ops[0].register, not current.ops[1].instant)
    else: discard

  of And:
    if current.layout @[okRegister, okRegister]:
      self.rem.store(current.ops[0].register, self.rem.peek(current.ops[0].register) and self.rem.peek(current.ops[1].register))
    elif current.layout @[okRegister, okInstant]:
      self.rem.store(current.ops[0].register, self.rem.peek(current.ops[0].register) and current.ops[1].instant)
    else: discard

  of Or:
    if current.layout @[okRegister, okRegister]:
      self.rem.store(current.ops[0].register, self.rem.peek(current.ops[0].register) or self.rem.peek(current.ops[1].register))
    elif current.layout @[okRegister, okInstant]:
      self.rem.store(current.ops[0].register, self.rem.peek(current.ops[0].register) or current.ops[1].instant)
    else: discard

  of Xor:
    if current.layout @[okRegister, okRegister]:
      self.rem.store(current.ops[0].register, self.rem.peek(current.ops[0].register) xor self.rem.peek(current.ops[1].register))
    elif current.layout @[okRegister, okInstant]:
      self.rem.store(current.ops[0].register, self.rem.peek(current.ops[0].register) xor current.ops[1].instant)
    else: discard

  of Compare:
    if current.layout @[okRegister, okRegister]:
      let dstValue = self.rem.peek(current.ops[0].register)
      let srcValue = self.rem.peek(current.ops[1].register)
      self.rem.store(current.ops[0].register, compare(dstValue, srcValue))
    elif current.layout @[okRegister, okInstant]:
      let dstValue = self.rem.peek(current.ops[0].register)
      let srcValue = current.ops[1].instant
      self.rem.store(current.ops[0].register, compare(dstValue, srcValue))
    else: discard

  of Jump:
    if current.layout @[okInstant]:
      self.pc = current.ops[0].instant.int
    elif current.layout @[okRegister]:
      self.pc = self.rem.peek(current.ops[0].register).int
    else: discard

  of JumpEQ:
    if current.layout @[okRegister, okInstant]:
      if self.rem.peek(current.ops[0].register) == 0b010:
        self.pc = current.ops[0].instant.int
    elif current.layout @[okRegister, okRegister]:
      if self.rem.peek(current.ops[0].register) == 0b010:
        self.pc = self.rem.peek(current.ops[1].register).int
    else: discard

  of JumpNE:
    if current.layout @[okRegister, okInstant]:
      if self.rem.peek(current.ops[0].register) != 0b010:
        self.pc = current.ops[0].instant.int
    elif current.layout @[okRegister, okRegister]:
      if self.rem.peek(current.ops[0].register) != 0b010:
        self.pc = self.rem.peek(current.ops[1].register).int
    else: discard

  of JumpGT:
    if current.layout @[okRegister, okInstant]:
      if self.rem.peek(current.ops[0].register) == 0b100:
        self.pc = current.ops[0].instant.int
    elif current.layout @[okRegister, okRegister]:
      if self.rem.peek(current.ops[0].register) == 0b100:
        self.pc = self.rem.peek(current.ops[1].register).int
    else: discard

  of JumpLT:
    if current.layout @[okRegister, okInstant]:
      if self.rem.peek(current.ops[0].register) == 0b001:
        self.pc = current.ops[0].instant.int
    elif current.layout @[okRegister, okRegister]:
      if self.rem.peek(current.ops[0].register) == 0b001:
        self.pc = self.rem.peek(current.ops[1].register).int
    else: discard

  of JumpGE:
    if current.layout @[okRegister, okInstant]:
      if self.rem.peek(current.ops[0].register) == 0b100 or self.rem.peek(current.ops[0].register) == 0b010:
        self.pc = current.ops[0].instant.int
    elif current.layout @[okRegister, okRegister]:
      if self.rem.peek(current.ops[0].register) == 0b100 or self.rem.peek(current.ops[0].register) == 0b010:
        self.pc = self.rem.peek(current.ops[1].register).int
    else: discard

  of JumpLE:
    if current.layout @[okRegister, okInstant]:
      if self.rem.peek(current.ops[0].register) == 0b001 or self.rem.peek(current.ops[0].register) == 0b010:
        self.pc = current.ops[0].instant.int
    elif current.layout @[okRegister, okRegister]:
      if self.rem.peek(current.ops[0].register) == 0b001 or self.rem.peek(current.ops[0].register) == 0b010:
        self.pc = self.rem.peek(current.ops[1].register).int
    else: discard

  of Label:
    if current.layout @[okInstant]:
      self.lem.newLabel(current.ops[0].instant, self.pc)
    else: discard

  of HeapAlloc:
    if current.layout @[okRegister, okInstant]:
      self.rem.store(current.ops[0].register, self.heapAlloc(current.ops[1].instant.int).uint64)

  else: echo "unknown: " & $self.code[self.pc]

  echo "------[ " & $self & " ]------"
  echo "reg0 = " & $self.rem.peek(0)
  echo "reg1 = " & $self.rem.peek(1)
  echo "labels = " & $self.lem.labels.mapIt(it[])
  echo "memory = " & $self.mem.chunks
  echo "-".repeat(16 + ($self).len)

  if incrementPC: inc self.pc
