# LED! Word — Hardware LED Control

## Synopsis

```forth
1 LED!    \ turn on LED D2
0 LED!    \ turn off LED D2
```

## Description

`LED! ( n -- )` writes the low bit of `n` to the COR24 LED register at memory address `0xFF0000`. Only bit 0 is used; all other bits are masked off.

This is the simplest hardware interaction available in tf24a — a single-bit write to a memory-mapped I/O register.

## Memory Map

| Address    | Register | Description |
|------------|----------|-------------|
| `0xFF0000` | LED      | Bit 0 = LED D2 (1=on, 0=off) |

## Implementation

`LED!` is a primitive word (assembler code, not a colon definition). It:

1. Pops `n` from the data stack
2. Masks `n` with `AND 1` to isolate the low bit
3. Stores the result to address `0xFF0000` via `sb`
4. Returns via NEXT

The signed 24-bit representation of `0xFF0000` is `-65536`, which is how the assembler encodes the address.

## Testing

### Threaded code test (runs at boot)

The test thread includes:
```
LIT 1
LED!
```
This turns on LED D2 during the boot sequence, before entering the interactive interpreter.

### Interactive tests

```
cor24-run --run forth.s -u '1 LED!\n' --speed 0 --dump
```

Check the dump output for:
```
FF0000 LED:  0x01  [.......*]
```

### Multi-line session

```
cor24-run --run forth.s -u '0 LED!\n1 LED!\n' --speed 0 --dump
```

First line turns LED off, second turns it back on. Final state: LED = 0x01.

## Related Words

- `!` — general memory store (`x addr -- `), available for any address
- `C!` — byte store (`c addr --`)
- `EMIT` — UART character output
