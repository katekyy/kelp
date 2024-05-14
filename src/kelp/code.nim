const
  MagicBytes*: array[0..1, uint8] = [0x4B, 0x42]

type
  OpKind* = enum
    okRegister
    okInstant
    okBytes

  Operand* = object
    case kind*: OpKind:
    of okRegister, okInstant: value*: uint64
    of okBytes: bytes*: seq[uint8]

  InstructionKind* = enum
    ikMove
    ikAdd
    ikSubtract
    ikCompare
    ikJump
    ikJumpEQ
    ikJumpNE
    ikJumpGT
    ikJumpLT
    ikJumpGE
    ikJumpLE
    ikWait # 11
    ikLabel
    ikCall
    ikReturn
    ikSpawn

  Instruction* = object
    kind*: InstructionKind
    ops*: seq[Operand]

  InvalidBytecodeError* = object of CatchableError

proc parseCode*(bytes: seq[uint8]): seq[Instruction] =
  if bytes.len < MagicBytes.len:
    # RAISE NEW ERROR
    discard
  for idx, magic in MagicBytes:
    if bytes[idx] != magic:
      # RAISE NEW ERROR
      discard

  var idx = MagicBytes.len

  while idx < bytes.len:
    var current = Instruction(
      kind: InstructionKind bytes[idx]
    )
    if idx + 1 >= bytes.len:
      raise newException(InvalidBytecodeError, "1")
    let argc = bytes[idx + 1].int
    inc idx, 2

    for _ in 0..argc - 1:
      var op = Operand(
        kind: OpKind bytes[idx]
      )
      inc idx
      case op.kind:
      of okRegister:
        op.value = (bytes[idx].uint64 shl 8) or bytes[idx + 1].uint64
        inc idx, 2
      of okInstant:
        let instantBytes = bytes[idx].int
        for i in 1..instantBytes:
          op.value = op.value or bytes[idx + i].uint64 shl ((instantBytes - i) * 8)
        inc idx, instantBytes + 1
      of okBytes:
        let bytesLen = bytes[idx].int
        for i in 1..bytesLen:
          op.bytes.add bytes[idx + i]
        inc idx, bytesLen + 1
      current.ops.add op

    result.add current
