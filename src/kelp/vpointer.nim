from std/strutils import toHex


type
  VirtualPointer* = distinct int


proc vpointer*(p: SomeInteger): VirtualPointer =
  result = cast[VirtualPointer](p)


proc `$`*(vp: VirtualPointer): string =
  result = cast[int](vp).toHex

proc toInt*(vp: VirtualPointer): SomeInteger =
  result = cast[int](vp)


proc `+`*(a, b: VirtualPointer): VirtualPointer =
  result = vpointer a.toInt + b.toInt

proc `+`*(a: SomeInteger, b: VirtualPointer): VirtualPointer =
  result = vpointer a + b.toInt

proc `+`*(a: VirtualPointer, b: SomeInteger): VirtualPointer =
  result = vpointer a.toInt + b


proc `-`*(a, b: VirtualPointer): VirtualPointer =
  result = vpointer a.toInt - b.toInt

proc `-`*(a: SomeInteger, b: VirtualPointer): VirtualPointer =
  result = vpointer a - b.toInt

proc `-`*(a: VirtualPointer, b: SomeInteger): VirtualPointer =
  result = vpointer a.toInt - b


proc `==`*(a, b: VirtualPointer): bool =
  result = a.toInt == b.toInt

proc `==`*(a: SomeInteger, b: VirtualPointer): bool =
  result = a == b.toInt

proc `==`*(a: VirtualPointer, b: SomeInteger): bool =
  result = a.toInt == b


proc `<`*(a, b: VirtualPointer): bool =
  result = a.toInt < b.toInt

proc `<`*(a: SomeInteger, b: VirtualPointer): bool =
  result = a < b.toInt

proc `<`*(a: VirtualPointer, b: SomeInteger): bool =
  result = a.toInt < b


proc `<=`*(a, b: VirtualPointer): bool =
  result = a < b or a == b

proc `<=`*(a: int, b: VirtualPointer): bool =
  result = a < b or a == b

proc `<=`*(a: VirtualPointer, b: int): bool =
  result = a < b or a == b


proc `>`*(a, b: VirtualPointer): bool =
  result = a.toInt > b.toInt

proc `>`*(a: SomeInteger, b: VirtualPointer): bool =
  result = a > b.toInt

proc `>`*(a: VirtualPointer, b: SomeInteger): bool =
  result = a.toInt > b


proc `>=`*(a, b: VirtualPointer): bool =
  result = a > b or a == b

proc `>=`*(a: int, b: VirtualPointer): bool =
  result = a > b or a == b

proc `>=`*(a: VirtualPointer, b: int): bool =
  result = a > b or a == b
