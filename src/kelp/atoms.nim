type
  Atom* = seq[uint8]

  AtomManager* = ref AtomManagerObject
  AtomManagerObject = object
    atoms*: seq[Atom]
    init*: bool

proc `$`*(a: AtomManager): string =
  result = "AtomTable"
  if not a.init:
    result &= "[not initialized]"
    return
  result &= "[\n"
  for atom in a.atoms:
    if atom.len <= 0: continue
    result &= "  "
    for idx in 0..atom.len - 1:
      result &= char atom[idx]
    result &= ",\n"
  result &= "]"

proc newAtomManager*(): AtomManager =
  result = new AtomManagerObject

proc initAtomManager*(self: AtomManager, size: int = 0) =
  self.atoms = newSeq[Atom](size)
  self.init = true

proc setAtom*(self: AtomManager, id: int, atom: Atom) =
  self.init = true
  let distance = self.atoms.len - id
  if distance == 0:
    self.atoms.add atom
  else:
    if distance < 0:
      for _ in 0..distance * -1: self.atoms.add newSeq[uint8]()
    self.atoms[id] = atom
