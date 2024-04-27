import ./[
  code,
  memory,
  vpointer
]


type
  Blade* = ref object
    id*: int = -1
    pc*: int
    mem*: MemoryManager
    code*: Code


proc newBlade*(mem: MemoryManager, id: int, code: seq[int16]): Blade =
  result = Blade(
    id: id,
    mem: mem
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
