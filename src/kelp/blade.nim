import ./[
  registers,
  vpointer,
  memory,
  atoms,
  code
]

import std/asyncdispatch


type
  Blade* = ref object
    id*: int = -1
    pc*: int
    mem*: MemoryManager
    rem*: RegisterManager
    atoms*: AtomManager
    code*: Code


proc newBlade*(mem: MemoryManager, id: int, code: seq[uint8]): Blade =
  result = Blade(
    id: id,
    mem: mem,
    rem: newRegisterManager(),
    atoms: newAtomManager(),
    code: parseCode code
  )

proc `$`*(b: Blade): string =
  result = "@" & $b.id

proc heapAlloc*(self: Blade, size: int): VirtualPointer =
  self.mem.alloc(self.id, size)

proc heapRealloc*(self: Blade, vp: VirtualPointer, newSize: int): VirtualPointer =
  self.mem.realloc(self.id, vp, newSize)

proc heapFree*(self: Blade, vp: VirtualPointer) =
  self.mem.free(self.id, vp)

proc heapSize*(self: Blade, vp: VirtualPointer): int =
  self.mem.size(self.id, vp)

proc start*(self: Blade) {.async.} =
  while self.pc < self.code.len:
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

    echo "------"
    echo "reg0 = " & $self.rem.peek(0)
    echo "reg1 = " & $self.rem.peek(1)
    echo "atoms = " & $self.atoms
    echo "------"

    if incrementPC: inc self.pc
    discard
