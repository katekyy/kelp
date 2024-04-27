import unittest
import std/os

import kelp/[
  memory,
  blade,
  kelp,
  vpointer,
]

test "1":
  let vm = newKelp()
  check true

test "memory manager":
  let
    mem = newMemoryManager()
    owner1 = 1
    owner2 = 2

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
    for chunk in mem.chunks:
      echo chunk.repr
