import std/strutils


const
  InstructionLength* = 2
  CharacterLength* = 1
  RegisterLength* = 2
  InstantLength* = 8


type
  InstructionKind* = enum
    Move
    Not
    And
    Or
    Xor
    Compare
    Jump
    JumpEQ
    JumpNE
    JumpGT
    JumpLT
    JumpGE
    JumpLE
    Label
    VMOpt
    HeapFree
    HeapAlloc
    HeapRealloc
    HeapDealloc
    HeapPeek
    HeapWrite

  ArgumentKind* = enum
    Register
    Instant
    Bytes

  ArgumentLayout* = enum
    Instant
    Bytes
    RegisterRegister
    RegisterInstant
    InstantInstant

  Argument* = object
    case kind*: ArgumentKind:
    of Register: register*: uint16
    of Instant: instant*: uint64
    of Bytes: bytes*: seq[uint8]

  Instruction* = object
    kind*: InstructionKind
    layout*: ArgumentLayout
    args*: seq[Argument]

  Code* = seq[Instruction]

  InstructionKindOutOfBoundsError* = object of CatchableError
  ArgumentLayoutOutOfBoundsError* = object of CatchableError
  TooFewArgumentsError* = object of CatchableError


#           Instruction (8bit)
#           |
#           |         Argument layout (8bit)
#           +-------- +--------
# b (16bit) 0000 0000 0000 0000

#           Instant value
#           +------------------------------------------------------------------------------
# b (64bit) 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000

#           Register number
#           +------------------
# b (16bit) 0000 0000 0000 0000

#           Heap address (dont need to implement?)
#           +------------------------------------------------------------------------------
# b (64bit) 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000

#   Bytes (64bit + 8bit * length)
#   +-------------------------------------------------------------------------------------------------- ...
#   Bytes Size (64bit)                                                              Byte (8bit)
#   +------------------------------------------------------------------------------ +-------- +-------- ...
# b 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0101 0000 0000 0000 0000


proc getInstant*(bytes: seq[uint8], start: int = 0): Argument =
  result.kind = Instant
  result.instant =
    (bytes[start    ].uint64 shl 56) or
    (bytes[start + 1].uint64 shl 48) or
    (bytes[start + 2].uint64 shl 40) or
    (bytes[start + 3].uint64 shl 32) or
    (bytes[start + 4].uint64 shl 24) or
    (bytes[start + 5].uint64 shl 16) or
    (bytes[start + 6].uint64 shl 8 ) or
     bytes[start + 7].uint64

proc getRegister*(bytes: seq[uint8], start: int = 0): Argument =
  result.kind = Register
  result.register = (bytes[start].uint16 shl 8) or bytes[start + 1].uint16

proc getBytes*(bytes: seq[uint8], start: int = 0, length: int): Argument =
  result.kind = Bytes
  result.bytes = newSeq[uint8](length)
  for i in 0..length - 1:
      result.bytes[i] = bytes[i]

proc getInstruction*(bytes: seq[uint8], start: int = 0): Instruction =
  let
    kind = bytes[start]
    layout = bytes[start + 1]

  if kind > uint8 InstructionKind.high:
    raise newException(InstructionKindOutOfBoundsError, "TODO: MSG")
  if layout > uint8 ArgumentLayout.high:
    raise newException(ArgumentLayoutOutOfBoundsError, "TODO: MSG")

  result.kind = InstructionKind kind
  result.layout = ArgumentLayout layout

proc inBounds(bytes: seq[uint8], idx: SomeInteger) =
  if idx.int >= bytes.len: raise newException(TooFewArgumentsError, "TODO: MSG")

proc parseCode*(bytes: seq[uint8]): Code =
  var idx = 0
  while idx < bytes.len:
    bytes.inBounds InstructionLength
    var instruction = bytes.getInstruction idx
    inc idx, InstructionLength

    case instruction.layout:
    of Instant:
      bytes.inBounds InstantLength
      instruction.args.add bytes.getInstant idx
      inc idx, InstantLength

    of Bytes:
      bytes.inBounds InstantLength
      let length = int bytes.getInstant(idx).instant
      inc idx, InstantLength
      bytes.inBounds length
      instruction.args.add bytes.getBytes(idx, length)

    of RegisterRegister:
      bytes.inBounds RegisterLength * 2
      instruction.args.add bytes.getRegister idx
      instruction.args.add bytes.getRegister idx + RegisterLength
      inc idx, RegisterLength * 2

    of RegisterInstant:
      bytes.inBounds RegisterLength + InstantLength
      instruction.args.add bytes.getRegister idx
      instruction.args.add bytes.getInstant idx + RegisterLength
      inc idx, RegisterLength + InstantLength

    else: discard

    echo instruction

    result.add instruction
