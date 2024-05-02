import kelp/[
  thread,
  memory
]

{.push warning[Deprecated]: off.}
import std/[
  os, cpuinfo, threadpool
]
{.pop.}

export
  thread

type
  ThreadState* = enum
    ThreadReady
    ThreadRunning
    ThreadExited
    ThreadTrapped

  ScheduledThread* = ref object
    priority*: int
    thread*: LightThread
    state*: ThreadState

  Scheduler* = ref object
    id*, ping*: int
    kelp*: Kelp
    shouldExit*: bool
    scheduledThreads*, exitedThreads*: seq[int]
    currentThread*, currentThreadTicks*: int

  Kelp* = ref object
    started*: bool
    threads*: seq[ScheduledThread]
    schedulers*: seq[Scheduler]
    latestScheduler*: int
    mem*: MemoryManager


proc newScheduler(kelp: Kelp, id: int): Scheduler =
  result = new Scheduler
  result.kelp = kelp
  result.id = id

proc newKelp*(): Kelp =
  result = new Kelp
  result.mem = newMemoryManager()
  result.schedulers = newSeq[Scheduler]( countProcessors() )
  for id in 0..result.schedulers.high:
    result.schedulers[id] = newScheduler(result, id)

proc getCurrentThread(self: Scheduler): ScheduledThread =
  result = self.kelp.threads[self.scheduledThreads[self.currentThread]]

proc switchThread(self: Scheduler): bool =
  if self.currentThreadTicks > 0:
    dec self.currentThreadTicks
    return
  self.currentThread = (self.currentThread + 1) mod self.scheduledThreads.len
  if self.getCurrentThread.state == ThreadExited:
    return true
  self.currentThreadTicks = self.getCurrentThread.priority

proc start(self: Scheduler) {.thread.} =
  while not self.kelp.started: sleep 1
  self.shouldExit = (self.scheduledThreads.len == self.exitedThreads.len) or self.scheduledThreads.len == 0
  while not self.shouldExit:
    self.ping = (self.ping + 1) mod int.high

    if self.scheduledThreads.len == 0:
      self.shouldExit = true
      continue
    if self.switchThread:
      sleep 1
      continue

    var vmopt: int
    try:
      vmopt = self.getCurrentThread.thread.step()
    except:
      echo "err"
      self.getCurrentThread.state = ThreadTrapped
      self.scheduledThreads.delete self.currentThread

    case vmopt:
    of 1:
      self.getCurrentThread.state = ThreadExited
      self.exitedThreads.add self.currentThread
    else: discard

proc scheduleThread(self: Scheduler, thread: int) =
  if self.exitedThreads.len > 0:
    self.scheduledThreads[self.exitedThreads.pop] = thread
  else:
    self.scheduledThreads.add thread
  spawn self.start

proc scheduleNewThread*(self: Kelp, code: seq[uint8], priority: range[0..255] = 0): int =
  let thread = ScheduledThread(
    priority: priority,
    thread: newLightThread(self.mem, self.threads.len, code)
  )
  self.threads.add thread
  self.schedulers[self.latestScheduler].scheduleThread(thread.thread.id)
  self.latestScheduler = (self.latestScheduler + 1) mod self.schedulers.len

proc start*(self: Kelp) {.thread.} =
  self.started = true
  sync()


when isMainModule:
  echo "NOT IMPLEMENTED"
