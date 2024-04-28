import ./[
  memory,
  blade
]


type
  Kelp* = ref object
    blades*: seq[Blade]
    mem*: MemoryManager


proc newKelp*(): Kelp =
  result = new Kelp

proc newBlade*(self: Kelp, code: seq[uint8]): Blade =
  let id = self.blades.len
  self.blades.add newBlade(
    self.mem,
    id,
    code
  )
  result = self.blades[id]

