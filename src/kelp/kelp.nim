import ./[
  memory,
  blade,
  code,
]


type
  Kelp* = ref object
    threads*: seq[Blade]
    mem*: MemoryManager


proc newKelp*(): Kelp =
  result = new Kelp

proc newBlade*(self: Kelp, code: seq[int16]) =
  self.threads.add newBlade(
    self.mem,
    self.threads.len,
    code
  )
