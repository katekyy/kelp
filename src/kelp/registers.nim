const RegisterCount = uint16.high.int + 1

type
  Register* = ptr uint64

  RegisterManager* = ref RegisterManagerObject
  RegisterManagerObject = object
    regs*: array[RegisterCount, Register]

proc newRegisters(): array[RegisterCount, Register] =
  for i in 0..RegisterCount - 1:
    result[i] = cast[ptr uint64]( alloc(8) )

proc `=destory`*(x: RegisterManagerObject) =
  for reg in x.regs:
    dealloc cast[pointer](reg)

proc newRegisterManager*(): RegisterManager =
  result = new RegisterManager
  result.regs = newRegisters()

proc write*(self: RegisterManager, reg: uint16, value: uint64) =
  self.regs[reg][] = value

proc peek*(self: RegisterManager, reg: uint16): uint64 =
  result = self.regs[reg][]
