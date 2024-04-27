# Code definition

import std/strutils


type
  InstructionKind* = enum
    Move
    Copy
    Not
    And
    Or
    Xor
    Compare
    Jump

  ArgumentLayout* = enum
    #Register
    Instant
    Address
    RegisterRegister
    RegisterInstant
    RegisterAddress
    InstantInstant

  CodeKind* = enum
    #           Instruction
    #           |
    #           |         Argument layout
    #           +-------- +--------
    # b (16bit) 0000 0000 0000 0000
    Instruction

    #           Instant value
    #           +------------------------------------------------------------------------------
    # b (64bit) 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
    Instant

    #           Register number
    #           +------------------
    # b (16bit) 0000 0000 0000 0000
    Register

    #           Heap address
    #           +------------------------------------------------------------------------------
    # b (64bit) 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
    Address

  Code* = object of RootObj
    case kind*: CodeKind:
    of Instruction:
      instruction*: InstructionKind
      argc*: int
      args*: seq[Code]
    of Instant:
      instant*: int
    of Register:
      register*: int
    of Address:
      address*: int


func `$`*(c: Code): string =
  case c.kind:
  of Instruction:
    result &= $c.instruction & "/" & $c.argc
    result &= "[" & c.args.join(", ") & "]"
  of Instant:
    result &= "i" & $c.instant
  of Register:
    result &= "r" & $c.register
  of Address:
    result &= "a" & $c.address

