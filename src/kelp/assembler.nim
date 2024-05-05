import ./code

import std/[
  strutils, tables
]

const instructions = {
  "move": Move,
  "label": Label,
  "halloc": HeapAlloc,
  "vmopt": VMOpt,
}.toTable

type
  TokenKind* = enum
    tkInstruction
    tkOperand
    tkColon
    tkEndOfLine

  Token* = object
    kind*: TokenKind
    literal*: string

  Operand* = object
    kind*: OperandKind
    literal*: string

proc scan*(content: string): seq[Token] =
  result = newSeqOfCap[Token](content.len div 2)
  var
    idx = 0
    buf: string
    comment: bool
  while idx < content.len:
    if comment:
      if content[idx] == '\n': comment = false
    else:
      case content[idx]:
      of ' ', '\t': discard
      of ';': comment = true
      of '\n', '\r':
        if buf.len > 0:
          result.add Token(literal: buf, kind: tkOperand)
          buf = ""
          result.add Token(kind: tkEndOfLine)
      of ',':
        if buf.len > 0:
          result.add Token(literal: buf, kind: tkOperand)
          buf = ""
      of ':':
        if buf.len > 0:
          result.add Token(literal: buf, kind: tkInstruction)
          buf = ""
        #result.add Token(kind: tkColon, literal: ":")
      else: buf &= content[idx]
    inc idx
  if buf.len > 0:
    result.add Token(literal: buf, kind: tkOperand)

proc parseOperand(literal: string): Operand =
  result.literal = literal[1..literal.high]
  case literal[0]:
  of '!': result.kind = okAtom
  of '#': result.kind = okRegister
  else:
    result.kind = okInstant
    result.literal = literal

proc instantBytes(bytes: var seq[uint8], i: uint64) =
  bytes.add ((i and 0xFF00_0000_0000_0000'u64) shr 56).uint8
  bytes.add ((i and 0xFF_0000_0000_0000'u64) shr 48).uint8
  bytes.add ((i and 0xFF00_0000_0000'u64) shr 40).uint8
  bytes.add ((i and 0xFF_0000_0000'u64) shr 32).uint8
  bytes.add ((i and 0xFF00_0000'u64) shr 24).uint8
  bytes.add ((i and 0xFF_0000'u64) shr 16).uint8
  bytes.add ((i and 0xFF00'u64) shr 8).uint8
  bytes.add ( i and 0xFF'u64).uint8

proc assemble*(content: string): seq[uint8] =
  result.add MagicBytes

  let tokens = scan content
  echo tokens

  var
    idx = 0
    atomID: uint64 = 0

  while idx < tokens.len:
    let current = tokens[idx]
    if current.kind != tkInstruction:
      echo "todo asm err1"
      return
    elif current.literal notin instructions:
      echo "todo asm err2"
      return
    else:
      let iKind = instructions[current.literal]
      var operands = newSeqOfCap[Operand](4)
      if idx + 1 >= tokens.len:
        echo "todo asm err3"
        return
      inc idx, 1
      while idx < tokens.len:
        echo tokens[idx].kind
        if tokens[idx].kind == tkEndOfLine:
          operands.add Operand(kind: okEnd)
          break
        elif tokens[idx].kind != tkOperand:
          echo "todo asm err5"
          return
        else:
          operands.add parseOperand(tokens[idx].literal)
        inc idx

      result.add uint8 iKind

      for op in operands:
        result.add uint8 op.kind
        case op.kind:
        of okRegister:
          let reg = op.literal.parseInt.uint16
          result.add ((reg and 0xFF00) shr 8).uint8
          result.add (reg and 0xFF).uint8
        of okAtom:
          result.instantBytes(atomID)
          for ch in op.literal:
            result.add ch.uint8
          inc atomID
        of okInstant:
          var i: uint64
          if op.literal.len >= 3 and op.literal[0] == '0':
            case op.literal[1]:
            of 'x': i = op.literal.fromHex[:uint64]
            of 'o': i = op.literal.fromOct[:uint64]
            of 'b': i = op.literal.fromBin[:uint64]
            else: discard
          else:
            i = op.literal.parseInt.uint64
          result.instantBytes(i)
        of okEnd: break
    inc idx
