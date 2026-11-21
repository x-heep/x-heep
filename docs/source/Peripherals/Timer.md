
# Timer SDK

This SDK provides utilities for execution time measurements using HW timers. It includes functions to start, stop, reset, and configure timers, as well as to enable timer interrupts and measure elapsed time.

## Usage

The SDK provides a set of functions to interact with the HW Timer for various timing operations.

### Initialize Timer for Counting Cycles

This function configures the counter at the running clock frequency to count the number of clock cycles. Call this function before the cycle-counting functions; `timer_wait_us` calls it itself. It returns `kRvTimerOk` on success, and an error when the SoC frequency reads as zero or the timer cannot be configured.

```c
rv_timer_result_t timer_cycles_init(void);
```

### Start Timer

Start the HW timer.

```c
void timer_start();
```

### Get Current Timer Value

Retrieve the current value of the HW timer without stopping it.

```c
uint32_t timer_get_cycles();
```

### Complete timer reset

Completely resets the HW counter, disabling all IRQs, counters, and comparators.
```c
void timer_reset();
```
 
### Stop Timer

Add the current value of the HW timer to the elapsed count, stop the counter and return the elapsed count. The counter is not reset.

```c
uint32_t timer_stop();
```

### Set Timer Threshold

Set the timer to go off once the counter value reaches the specified threshold. If the timer interrupts and the timer IRQ have been enabled, when the timer reaches that value an interrupt will be called.

```c
void timer_arm_set(uint32_t threshold);
```

### Set Timer Threshold and Start

Set the timer to go off once the counter value reaches the specified threshold, and start the timer. If the timer interrupts and the timer IRQ have been enabled, when the timer reaches that value an interrupt will be called.

```c
void timer_arm_start(uint32_t threshold);
```

### Enable Timer IRQ

Enable the timer interrupt request.

```c
void timer_irq_enable();
```

### Clear Timer IRQ

Clear the timer interrupt request.

```c
void timer_irq_clear();
```

### Enable Timer Machine-level Interrupts

Enable the timer machine-level interrupts for the X-Heep platform.

```c
void enable_timer_interrupt();
```

### Wait for Microseconds

Block execution for a specified number of microseconds. This function is not precise for small numbers of microseconds. Enable timer interrupts with `enable_timer_interrupt()` before using this function.

```c
void timer_wait_us(uint32_t us);
```

### Get Execution Time in Microseconds

Get the time taken to execute a certain number of cycles, returned as a float representing the time in microseconds.

```c
float get_time_from_cycles(uint32_t cycles);
```

## Example Usage

An example of utilization of the timer SDK can be found in `sw/applications/example_timer_sdk/main.c`.
