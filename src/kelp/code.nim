import std/strutils


const
  MagicBytes* = [0x4B'u8, 0x42]
  MagicBytesCompressed* = [0x4B'u8, 0x43]

  InstructionLength* = 1
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
    Label # 13
    Goto
    HeapFree
    HeapAlloc
    HeapRealloc
    HeapDealloc
    HeapPeek
    HeapWrite
    AtomicGroup
    Send
    Recieve
    FunctionSpec
    FunctionCall
    VMOpt

  OperandKind* = enum
    okRegister
    okInstant
    okAtom
    okEnd = 0xF

  Operand* = object
    case kind*: OperandKind:
    of okRegister: register*: uint16
    of okInstant: instant*: uint64
    of okAtom:
      id*: uint64
      bytes*: seq[uint8]
    of okEnd: discard

  Instruction* = object
    kind*: InstructionKind
    ops*: seq[Operand]

  Code* = seq[Instruction]

  InstructionKindOutOfBoundsError* = object of CatchableError
  OperandKindOutOfBoundsError* = object of CatchableError
  InvalidBytecodeError* = object of CatchableError
  TooFewOperandsError* = object of CatchableError
  ByteRangeError* = object of CatchableError


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
#   +-------------------------------------------------------------------------------------------------- ...
#   Atom Size (64bit)                                                               Bytes ([]8bit)
#   +------------------------------------------------------------------------------ +-------- +-------- ...
# b 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0101 0000 0000 0000 0000


proc getOpKind*(bytes: seq[uint8], start: int): OperandKind =
  let i = bytes[start].int
  if not (i in 0..2 or i == OperandKind.high.int):
    raise newException(OperandKindOutOfBoundsError, "TODO: MSG")
  result = cast[OperandKind]( i )

proc getInstant*(bytes: seq[uint8], start: int): Operand =
  result.kind = okInstant
  result.instant =
    (bytes[start    ].uint64 shl 56) or
    (bytes[start + 1].uint64 shl 48) or
    (bytes[start + 2].uint64 shl 40) or
    (bytes[start + 3].uint64 shl 32) or
    (bytes[start + 4].uint64 shl 24) or
    (bytes[start + 5].uint64 shl 16) or
    (bytes[start + 6].uint64 shl 8 ) or
     bytes[start + 7].uint64

proc getRegister*(bytes: seq[uint8], start: int): Operand =
  if bytes.len - start + 1 < RegisterLength:
    raise newException(TooFewOperandsError, "TODO: MSG")
  result.kind = okRegister
  result.register = (bytes[start].uint16 shl 8) or bytes[start + 1].uint16

proc getAtom*(bytes: seq[uint8], start: int): Operand =
  if bytes.len - start < InstantLength:
    raise newException(TooFewOperandsError, "TODO: MSG")
  let length = bytes.getInstant(start).instant.int

  result.kind = okAtom
  result.bytes = newSeq[uint8](length)

  if bytes.len - start < length:
    raise newException(TooFewOperandsError, "TODO: MSG")

  for i in 0..length - 1:
    let b = bytes[start + InstantLength + i]
    if not (b in 65'u8..90'u8 or b in 97'u8..122'u8 or b in 48'u8..57'u8):
      raise newException(
        ByteRangeError,
        "byte " & $b & " at index " & $i & " of atom at " & $(start - InstantLength) & " is not in range of: 48..57, 65..90 or 96..122"
      )
    result.bytes[i] = b

proc getInstruction*(bytes: seq[uint8], start: int): ref Instruction =
  result = new Instruction
  if bytes.len - start < InstructionLength:
    raise newException(TooFewOperandsError, "TODO: MSG")
  let kind = bytes[start]
  if kind > uint8 InstructionKind.high:
    raise newException(InstructionKindOutOfBoundsError, "TODO: MSG")
  result.kind = InstructionKind kind

proc parseCode*(bytes: seq[uint8]): Code =
  for idx, magic in MagicBytes:
    if bytes[idx] != magic:
      raise newException(InvalidBytecodeError, "TODO: MSG")
  var
    idx = MagicBytes.len
    current: ref Instruction

  while idx < bytes.len:
    if current.isNil:
      current = bytes.getInstruction(idx)
      inc idx, InstructionLength
    else:
      let opKind = bytes.getOpKind(idx)
      inc idx
      case opKind:
      of okRegister:
        current.ops.add bytes.getRegister(idx)
        inc idx, RegisterLength
      of okInstant:
        current.ops.add bytes.getInstant(idx)
        inc idx, InstantLength
      of okAtom:
        let atom = bytes.getAtom(idx)
        current.ops.add atom
        inc idx, InstantLength + atom.bytes.len
      of okEnd:
        result.add current[]
        current = nil
