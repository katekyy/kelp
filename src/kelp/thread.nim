import ./[
  registers,
  vpointer,
  memory,
  atoms,
  code
]


type
  LightThread* = ref object
    id*: int = -1
    pc*: int
    mem*: MemoryManager
    rem*: RegisterManager
    atoms*: AtomManager
    code*: Code


proc newLightThread*(mem: MemoryManager, id: int, code: seq[uint8]): LightThread =
  result = LightThread(
    id: id,
    mem: mem,
    rem: newRegisterManager(),
    atoms: newAtomManager(),
    code: parseCode code
  )

proc `$`*(b: LightThread): string =
  result = "@" & $b.id

proc heapAlloc*(self: LightThread, size: int): VirtualPointer =
  self.mem.alloc(self.id, size)

proc heapRealloc*(self: LightThread, vp: VirtualPointer, newSize: int): VirtualPointer =
  self.mem.realloc(self.id, vp, newSize)

proc heapFree*(self: LightThread, vp: VirtualPointer) =
  self.mem.free(self.id, vp)

proc heapSize*(self: LightThread, vp: VirtualPointer): int =
  self.mem.size(self.id, vp)

proc step*(self: LightThread): int =
  if self.pc == self.code.len: return 1

  var incrementPC = true
  let current = self.code[self.pc]

  case current.kind:
  of Move:
    case current.layout:
    of RegisterInstant:
      self.rem.write(current.operands[0].register, current.operands[1].instant)
    of RegisterRegister:
      self.rem.write(current.operands[0].register, self.rem.peek(current.operands[1].register))
    else: discard

  of Compare:
    let dstValue = self.rem.peek(current.operands[0].register)
    let compareSrc =
      if current.layout == RegisterInstant:
        current.operands[1].instant
      elif current.layout == RegisterRegister:
        self.rem.peek(current.operands[1].register)
      else: 0 # TODO ERROR

    var compareResult: uint64 = 0
    if dstValue == compareSrc:
      compareResult = 0b010
    elif dstValue > compareSrc:
      compareResult = 0b100
    elif dstValue < compareSrc:
      compareResult = 0x001

    self.rem.write(current.operands[0].register, compareResult)

  of AtomTable:
    if current.layout != InstantAtom: discard # ERROR
    var idx = 1 # 0 is the table size
    let tableSize = current.operands[0].instant.int
    self.atoms.initAtomManager(tableSize)

    while idx < tableSize + 1:
      self.atoms.setAtom(current.operands[idx].instant.int, current.operands[idx + 1].bytes)
      inc idx, 2

  else: echo "unknown: " & $self.code[self.pc]

  echo "------" & $self
  echo "reg0 = " & $self.rem.peek(0)
  echo "reg1 = " & $self.rem.peek(1)
  echo "atoms = " & $self.atoms
  echo "------"

  if incrementPC: inc self.pc
