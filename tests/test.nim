import unittest

import std/threadpool

import kelp
import kelp/[
  memory,
  vpointer,
]


test "vm":
  let vm = newKelp()
  discard vm.scheduleNewBlade(
    @[75'u8, 66, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 255, 15, 13, 1, 0, 0, 0, 0, 0, 0, 0, 1, 15, 13, 1, 0, 0, 0, 0, 0, 0, 0, 0, 15, 16, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 8, 15, 16, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 8, 15]
  )
  vm.start()


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
