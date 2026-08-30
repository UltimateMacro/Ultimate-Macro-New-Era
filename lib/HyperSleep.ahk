HyperSleep(ms)
{
    if (ms <= 0)
        return

    static freq := (DllCall("QueryPerformanceFrequency", "Int64*", &f := 0), f)

    DllCall("QueryPerformanceCounter", "Int64*", &begin := 0)
    finish := begin + (ms * freq / 1000)
    current := begin

    ; Sleep for the coarse part of the delay and reserve only a very small tail
    ; for the high-resolution spin. This keeps placement timing accurate without
    ; burning a CPU core for the whole requested delay.
    loop {
        DllCall("QueryPerformanceCounter", "Int64*", &current)
        remainingMs := (finish - current) * 1000 / freq

        if (remainingMs <= 1.25)
            break

        sleepMs := Max(1, Floor(remainingMs - 1.0))
        DllCall("Kernel32.dll\Sleep", "UInt", sleepMs)
    }

    while (current < finish)
        DllCall("QueryPerformanceCounter", "Int64*", &current)
}
