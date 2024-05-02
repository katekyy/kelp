import std/strutils


const
  InstructionLength* = 2
  RegisterLength* = 2
  InstantLength* = 8


type
  InstructionKind* = enum
    Move # 0
    Not
    And
    Or
    Xor
    Compare
    Jump
    JumpEQ
    JumpNE # 8
    JumpGT
    JumpLT
    JumpGE
    JumpLE
    AtomTable # 13
    Goto
    Label
    FunctionSpec
    FunctionCall
    VMOpt # 18
    HeapFree
    HeapAlloc
    HeapRealloc
    HeapDealloc
    HeapPeek
    HeapWrite

  OperandKind* = enum
    Register
    Instant
    Atom

  OperandLayout* = enum
    Instant
    RegisterRegister
    RegisterInstant
    InstantInstant
    InstantAtom
    InstantInstantInstant
    InstantVariadic

  Operand* = object
    case kind*: OperandKind:
    of Register: register*: uint16
    of Instant: instant*: uint64
    of Atom:
      id*: uint64
      bytes*: seq[uint8]

  Instruction* = object
    kind*: InstructionKind
    layout*: OperandLayout
    operands*: seq[Operand]

  Code* = seq[Instruction]

  InstructionKindOutOfBoundsError* = object of CatchableError
  OperandLayoutOutOfBoundsError* = object of CatchableError
  TooFewOperandsError* = object of CatchableError
  AtomNotInRangeError* = object of CatchableError


#           Instruction (8bit)
#           |
#           |         Operand layout (8bit)
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

#   Atom (64bit + 8bit * size)
#   +---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ...
#   Atom ID (64bit)                                                                 Atom Size (64bit)                                                               Bytes ([]8bit)
#   +------------------------------------------------------------------------------ +------------------------------------------------------------------------------ +-------- +-------- ...
# b 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0101 0000 0000 0000 0000

#   Variadic (64bit + 16bit * count)
#   +------------------------------------------------------------------------------------------------------------...
#   Register Count (64bit)                                                          Argument (16bit)
#   +------------------------------------------------------------------------------ +------------------...
# b 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000


proc getInstant*(bytes: seq[uint8], start: int = 0): Operand =
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

proc getRegister*(bytes: seq[uint8], start: int = 0): Operand =
  result.kind = Register
  result.register = (bytes[start].uint16 shl 8) or bytes[start + 1].uint16

proc getAtom*(bytes: seq[uint8], start: int = 0, length: int): Operand =
  result.kind = Atom
  result.bytes = newSeq[uint8](length)
  for i in 0..length - 1:
    let b = bytes[start + i]
    if not (b in 65'u8..90'u8 or b in 97'u8..122'u8 or b in 48'u8..57'u8):
      raise newException(
        AtomNotInRangeError,
        "byte " & $b & " at index " & $i & " of atom at " & $(start - InstantLength) & " is not in range of: 48..57, 65..90 or 96..122"
      )
    result.bytes[i] = b

proc getInstruction*(bytes: seq[uint8], start: int = 0): Instruction =
  let
    kind = bytes[start]
    layout = bytes[start + 1]

  if kind > uint8 InstructionKind.high:
    raise newException(InstructionKindOutOfBoundsError, "TODO: MSG")
  if layout > uint8 OperandLayout.high:
    raise newException(OperandLayoutOutOfBoundsError, "TODO: MSG")

  result.kind = InstructionKind kind
  result.layout = OperandLayout layout

proc inBounds(bytes: seq[uint8], idx: SomeInteger, msg: string) =
  if bytes.len - idx.int <= 0:
    raise newException(
      TooFewOperandsError,
      msg & " expected overall of " & $(bytes.len + idx.int) & " bytes but got " & $bytes.len
    )

proc parseCode*(bytes: seq[uint8]): Code =
  var idx = 0
  while idx < bytes.len:
    bytes.inBounds InstructionLength, "instruction at index " & $idx
    var instruction = bytes.getInstruction(idx)
    inc idx, InstructionLength

    case instruction.layout:
    of Instant:
      bytes.inBounds InstantLength, "instant at index " & $idx
      instruction.operands.add bytes.getInstant(idx)
      inc idx, InstantLength

    of RegisterRegister:
      bytes.inBounds RegisterLength * 2, "register"
      instruction.operands.add bytes.getRegister idx
      instruction.operands.add bytes.getRegister idx + RegisterLength
      inc idx, RegisterLength * 2

    of RegisterInstant:
      bytes.inBounds RegisterLength + InstantLength, "register and instant"
      instruction.operands.add bytes.getRegister idx
      instruction.operands.add bytes.getInstant idx + RegisterLength
      inc idx, RegisterLength + InstantLength

    of InstantAtom:
      bytes.inBounds InstantLength, "instant"
      let tableSize = bytes.getInstant(idx)
      instruction.operands.add tableSize
      inc idx, InstantLength

      for _ in 0..tableSize.instant - 1:
        bytes.inBounds InstantLength * 2, "atom's ID and size are instants, thus they "
        instruction.operands.add bytes.getInstant(idx)
        let length = bytes.getInstant(idx + InstantLength).instant.int
        bytes.inBounds length, "atom"

        instruction.operands.add bytes.getAtom(
          idx + InstantLength * 2,
          length
        )

        inc idx, InstantLength * 2 + length

    of InstantVariadic:
      bytes.inBounds InstantLength * 2, ""

    else: discard

    echo instruction

    result.add instruction
