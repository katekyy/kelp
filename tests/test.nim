import unittest
import kelp

import kelp/code

import std/[os, threadpool]

test "1":
  let vm = newKelp()
  #                  magic bytes    move #0, 65535                 add #0, 1               sleep 500            jump 0
  #                  vvvvvvvvvvvvv  vvvvvvvvvvvvvvvvvvvvvvvvvvvvv  vvvvvvvvvvvvvvvvvvvvvv  vvvvvvvvvvvvvvvvvvv  vvvvvvvvvvvvv
  echo vm.newBlade @[0x4b'u8, 0x42, 0, 2, 0, 0, 0, 1, 2, 255, 255, 1, 2, 0, 0, 0, 1, 1, 1, 11, 1, 1, 2, 3, 232, 4, 1, 1, 1, 0]
  echo vm.newBlade @[0x4b'u8, 0x42, 0, 2, 0, 0, 0, 1, 2, 255, 255, 1, 2, 0, 0, 0, 1, 1, 1, 11, 1, 1, 2, 3, 232, 4, 1, 1, 1, 0]
  spawn vm.start()

  for _ in 1..10:
    sleep 10
    echo "spawning another: " & $vm.newBlade(@[0x4b'u8, 0x42, 0, 2, 0, 0, 0, 1, 2, 255, 255, 1, 2, 0, 0, 0, 1, 1, 1, 11, 1, 1, 2, 3, 232, 4, 1, 1, 1, 0])

  sync()
  check true
