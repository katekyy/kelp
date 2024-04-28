import ./vpointer

from std/strutils import repeat

const ChunkSize = 1

var allocUID: uint = 0


type
  Chunk* = ref object
    vp*: VirtualPointer
    allocUID*: uint
    ownerID*: int
    data*: pointer

  MemoryManager* = ref MemoryManagerObject
  MemoryManagerObject* = object
    chunks*: seq[Chunk]
    greedy*: bool
    capacity*: HSlice[int, int]

  InvalidMemoryAddressError* = object of CatchableError
  UnprivilegedAccessError* = object of CatchableError
  InvalidRegionSizeError* = object of CatchableError


proc `$`*(cs: seq[Chunk], columns: int = 4): string =
  var longestID = 0
  for c in cs:
    if c.ownerID < 0: continue
    if ($c.ownerID).len > longestID: longestID = ($c.ownerID).len

  for i, c in cs:
    result &= $c.vp & "["
    if c.ownerID < 0:
      result &= " ".repeat(longestID) & " ~" & c.data.repr & "]"
    else:
      result &= "@" & $c.ownerID & "~" & c.data.repr & "]"
    result &= " | "
    if i mod columns == (columns - 1): result &= "\n"

proc error(self: MemoryManager, accessor: int, err: typedesc, msg: string) =
  raise newException(err, "@" & $accessor & " - invalid memory access: " & msg)

proc `=destroy`*(x: MemoryManagerObject) =
  for chunk in x.chunks:
    dealloc chunk.data

proc newMemoryManager*(capacity: HSlice[int, int] = HSlice[int, int](a: 0, b: -1), greedy: bool = false): MemoryManager =
  result = new MemoryManager
  result.capacity = capacity
  result.greedy = greedy

proc addChunk*(self: MemoryManager, ownerID: int, allocUID: uint) =
  let data = alloc(ChunkSize)
  cast[ptr uint8](data)[] = 0
  self.chunks.add Chunk(
    vp: vpointer self.chunks.len,
    allocUID: allocUID,
    ownerID: ownerID,
    data: data
  )

proc seekFree*(self: MemoryManager, start: VirtualPointer = vpointer 0): tuple[start: VirtualPointer, size: int] =
  result.start = vpointer -1
  for idx, chunk in self.chunks[start..self.chunks.high]:
    if chunk.ownerID < 0:
      if result.start < 0:
        result.start = vpointer idx
      inc result.size

    if result.start >= 0 and not chunk.ownerID < 0:
      return

proc seekFreeSized*(self: MemoryManager, size: SomeInteger = 1): tuple[start: VirtualPointer, size: int] =
  result.start = vpointer -1
  var start = vpointer 0
  while start < self.chunks.len:
    let free = self.seekFree(start)

    if free.start == -1: return
    if free.size >= size: return free

    start = free.start + free.size

proc seekFreeLast*(self: MemoryManager): int =
  result = -1
  if self.chunks.len == 0 or not self.chunks[self.chunks.high].ownerID < 0: return
  result = self.chunks.high
  while result != 0 and self.chunks[result].ownerID < 0:
    dec result
  if not self.chunks[result].ownerID < 0:
    inc result

## if accessor is `-1` there's no ownership check
iterator peekChunks*(self: MemoryManager, accessor: int, vp: VirtualPointer): Chunk =
  if vp.int >= self.chunks.len:
    self.error(accessor, InvalidMemoryAddressError, "address " & $vp & " is out of range")
  if accessor >= 0 and self.chunks[int vp].ownerID != accessor:
    self.error(accessor, UnprivilegedAccessError, "unprivileged access to memory at 0x" & $vp)
  var idx = int vp
  while idx < self.chunks.len and self.chunks[idx].ownerID == accessor and self.chunks[idx].allocUID == self.chunks[int vp].allocUID:
    yield self.chunks[idx]
    inc idx

func size*(self: MemoryManager, accessor: int, vp: VirtualPointer): int =
  for _ in self.peekChunks(accessor, vp):
    inc result

proc alloc*(self: MemoryManager, accessor: int, size: range[1..int.high]): VirtualPointer =
  let free = self.seekFreeSized(size)
  if free.start < 0:
    let freeLast = self.seekFreeLast()

    if freeLast >= 0:
      result = vpointer freeLast
      let freeLastLen = self.size(-1, vpointer freeLast)

      for i in freeLast..self.chunks.high:
        self.chunks[i].ownerID = accessor
        self.chunks[i].allocUID = allocUID

      for _ in 1..size - freeLastLen:
        self.addChunk(accessor, allocUID)

    else:
      result = vpointer self.chunks.len
      for _ in 1..size:
        self.addChunk(accessor, allocUID)
      inc allocUID
  else:
    result = vpointer free.start.int

    let rangeEnd: int =
      if self.greedy:
        int free.start + free.size - 1
      else: int free.start + size - 1

    for idx in free.start.int..rangeEnd:
      self.chunks[idx].ownerID = accessor
      self.chunks[idx].allocUID = allocUID
    inc allocUID

proc free*(self: MemoryManager, accessor: int, vp: VirtualPointer) =
  for chunk in self.peekChunks(accessor, vp):
    cast[ptr uint8](chunk.data)[] = 0
    chunk.ownerID = -1

proc dealloc*(self: MemoryManager, accessor: int, vp: VirtualPointer) =
  let
    vpi = int vp
    startUID = self.chunks[vpi].allocUID
  while vp < self.chunks.len and self.chunks[vpi].ownerID == accessor and self.chunks[vpi].allocUID == startUID:
    dealloc self.chunks[vpi].data
    self.chunks.delete(vpi)

iterator peekAll*(self: MemoryManager, accessor: int, vp: VirtualPointer): uint8 =
  for chunk in self.peekChunks(accessor, vp):
    yield cast[ptr uint8](chunk.data)[]

proc peek*(self: MemoryManager, accessor: int, vp: VirtualPointer): uint8 =
  for b in self.peekAll(accessor, vp):
    return b

proc write*(self: MemoryManager, accessor: int, vp: VirtualPointer, value: uint8) =
  for chunk in self.peekChunks(accessor, vp):
    cast[ptr uint8](chunk.data)[] = value
    return

proc move*(self: MemoryManager, accessor: int, vpSrc, vpDst: VirtualPointer) =
  let
    srcLen = self.size(accessor, vpSrc)
    dstLen = self.size(accessor, vpDst)
  if srcLen > dstLen:
    self.error(accessor, InvalidRegionSizeError, "move destination cannot be smaller than the source.")
  for i in 0..srcLen - 1:
    self.write(accessor, vpDst + i, self.peek(accessor, vpSrc + i))
    cast[ptr uint8](self.chunks[int vpSrc + i].data)[] = 0
    self.chunks[int vpSrc + i].ownerID = -1

proc realloc*(self: MemoryManager, accessor: int, vp: VirtualPointer, newSize: int): VirtualPointer =
  result = vp
  let length = self.size(accessor, vp)
  if length > newSize:
    self.free(accessor, vp + newSize)
  elif length < newSize:
    let newVp = self.alloc(accessor, newSize)
    self.move(accessor, vp, newVp)
    result = newVp
