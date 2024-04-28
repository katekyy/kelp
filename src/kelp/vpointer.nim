from std/strutils import toHex


type
  VirtualPointer* = distinct int


proc vpointer*(p: SomeInteger): VirtualPointer =
  result = cast[VirtualPointer](p)


proc `$`*(vp: VirtualPointer): string =
  result = vp.int.toHex


proc `+`*(a, b: VirtualPointer): VirtualPointer =
  result = vpointer a.int + b.int

proc `+`*(a: SomeInteger, b: VirtualPointer): VirtualPointer =
  result = vpointer a + b.int

proc `+`*(a: VirtualPointer, b: SomeInteger): VirtualPointer =
  result = vpointer a.int + b


proc `-`*(a, b: VirtualPointer): VirtualPointer =
  result = vpointer a.int - b.int

proc `-`*(a: SomeInteger, b: VirtualPointer): VirtualPointer =
  result = vpointer a - b.int

proc `-`*(a: VirtualPointer, b: SomeInteger): VirtualPointer =
  result = vpointer a.int - b


proc `==`*(a, b: VirtualPointer): bool =
  result = a.int == b.int

proc `==`*(a: SomeInteger, b: VirtualPointer): bool =
  result = a == b.int

proc `==`*(a: VirtualPointer, b: SomeInteger): bool =
  result = a.int == b


proc `<`*(a, b: VirtualPointer): bool =
  result = a.int < b.int

proc `<`*(a: SomeInteger, b: VirtualPointer): bool =
  result = a < b.int

proc `<`*(a: VirtualPointer, b: SomeInteger): bool =
  result = a.int < b


proc `<=`*(a, b: VirtualPointer): bool =
  result = a < b or a == b

proc `<=`*(a: int, b: VirtualPointer): bool =
  result = a < b or a == b

proc `<=`*(a: VirtualPointer, b: int): bool =
  result = a < b or a == b


proc `>`*(a, b: VirtualPointer): bool =
  result = a.int > b.int

proc `>`*(a: SomeInteger, b: VirtualPointer): bool =
  result = a > b.int

proc `>`*(a: VirtualPointer, b: SomeInteger): bool =
  result = a.int > b


proc `>=`*(a, b: VirtualPointer): bool =
  result = a > b or a == b

proc `>=`*(a: SomeInteger, b: VirtualPointer): bool =
  result = a > b or a == b

proc `>=`*(a: VirtualPointer, b: SomeInteger): bool =
  result = a > b or a == b
