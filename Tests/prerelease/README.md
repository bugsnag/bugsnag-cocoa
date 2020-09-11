# Pre-release Checks

This section is intended for tests that cannot be performed in the current automated test infrastructure.

## Siri interrupts

1. Open a test app;
1. Trigger Siri;
1. Close and open the test app;
1. Ensure no OOM event is sent.

This was previously automated using the `out_of_memory.feature` in this directory, but it requires work
for it to run following the introduction of BrowserStack to MazeRunner (ref. PLAT-5040).