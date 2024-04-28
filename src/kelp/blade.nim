import ./[
  registers,
  vpointer,
  memory,
  code
]

import std/asyncdispatch


type
  Blade* = ref object
    id*: int = -1
    pc*: int
    mem*: MemoryManager
    rem*: RegisterManager
    code*: Code


proc newBlade*(mem: MemoryManager, id: int, code: seq[uint8]): Blade =
  result = Blade(
    id: id,
    mem: mem,
    rem: newRegisterManager(),
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
        self.rem.write(current.args[0].register, current.args[1].instant)
      of RegisterRegister:
        self.rem.write(current.args[0].register, self.rem.peek(current.args[1].register))
      else: discard
    else: echo self.code[self.pc]

    echo "reg0 = " & $self.rem.peek(0)
    echo "reg1 = " & $self.rem.peek(1)

    if incrementPC: inc self.pc
    discard
