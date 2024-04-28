import unittest
import std/asyncdispatch

import kelp/[
  memory,
  blade,
  kelp,
  vpointer,
]


test "vm":
  let vm = newKelp()
  asyncCheck vm.newBlade(@[
    0x0'u8, 0x3, 0x0, 0x0, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0x0, 0x2, 0x0, 0x1, 0x0, 0x0,
  ]).start()


test "memory manager":
  let
    mem = newMemoryManager()
    owner1 = 0
    owner2 = 1

  try:
    discard mem.size(owner1, vpointer 0)
    check false
  except InvalidMemoryAddressError: check true

  let p1 = mem.alloc(owner2, 4)
  check p1 == 0
  check mem.seekFreeLast() == -1

  mem.free(owner2, p1)

  let p2 = mem.alloc(owner1, 3)

  check p2 == 0
  check mem.seekFreeLast() == 3

  let p3 = mem.realloc(owner1, p2, 8)

  check p3 == 3
  check mem.seekFreeLast() == -1
  check mem.size(owner1, p3) == 8

  when defined(debug):
    echo mem.chunks
