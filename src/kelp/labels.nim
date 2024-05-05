type
  LabelManager* = ref object
    labels*: seq[ptr int64]

  LabelAlreadySetError* = object of CatchableError
  LabelNotFoundError* = object of CatchableError

proc newLabelManager*(): LabelManager =
  result = new LabelManager

proc newLabel*(self: LabelManager, id: SomeInteger, pc: int) =
  let distance = self.labels.high - id.int
  if distance == 0:
    self.labels.add cast[ptr int64]( alloc0(8) )
    self.labels[self.labels.high][] = -1
  else:
    if distance < 0:
      for _ in 0..distance * -1 - 1:
        self.labels.add cast[ptr int64]( alloc0(8) )
        self.labels[self.labels.high][] = -1
    if self.labels[id][] >= 0:
      raise newException(LabelAlreadySetError, "TODO: MSG")
    self.labels[id][] = pc.int64

proc getLabel*(self: LabelManager, id: SomeInteger): int =
  if self.high < id or self.labels[id][] < 0:
    raise newException(LabelNotFoundError, "TODO: MSG")
  result = self.labels[id][].int
