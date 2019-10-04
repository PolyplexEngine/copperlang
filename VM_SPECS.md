# Virtual Machine Specifications (Work in Progress)
The Copper VM is a register based VM, borrowing concepts from ARM and X86.

&nbsp;

## Registers
The VM has 8 general purpose registers (GP0 to GP7) as well 4 floating point registers (FP0 to FP3)

**Note:** GP0 and GP1 will be overwritten if doing multiplication with QWORDS.

| Register ID   | Usage               | Notes                             |
|---------------|:-------------------:|-----------------------------------|
| GP0           | General Purpose     | Append data size                  |
| GP1           | General Purpose     | Append data size                  |
| GP2           | General Purpose     | Append data size                  |
| GP3           | General Purpose     | Append data size                  |
| GP4           | General Purpose     | Append data size                  |
| GP5           | General Purpose     | Append data size                  |
| GP6           | General Purpose     | Append data size                  |
| GP7           | General Purpose     | Append data size                  |
| FP0           | Floating Point      | Single Precision                  |
| FP1           | Floating Point      | Single Precision                  |
| FP2           | Floating Point      | Double Precision                  |
| FP3           | Floating Point      | Double Precision                  |
| ESP           | Stack Pointer       | Mostly modified using pop/push    |
| FLG           | Flag Register       | Flags not accesible directly      |
| IP            | Instruction Pointer | Modified via JUMP instructions    |

&nbsp;

### Notes

Datasize is essentially splitting up the 8 byte wide registers in to smaller registers, think of a register as a C union.
Though the VM ISA understands the type sizes specified in instructions and will use data accordingly.
Do be aware of data overlap.


When appending datasize in copper asm, do the following:
 *   `.byte`
 *   `.word`
 *   `.dword`
 *   `.qword`
 *   `.ptrword`

For example: 
```
GP0.byte
GP1.ptrword
etc...
```

Implicitly ptrword will be used.
PTRWord is DWORD on 32 bit systems, QWORD on 64 bit systems.

&nbsp;

## Flags

| Flag Name     | Bitmask        | Usage                                          |
|---------------|:--------------:|------------------------------------------------|
| Larger Than   |0000000000000001| Set if value A was larger than B               |
| Equal         |0000000000000010| Set if value A was equal to B                  |
| Sign          |0000000000000100| Set if value A was negative                    |
| Zero          |0000000000001000| Set if value A was zero                        |
| Overflow      |0000000000010000| Set if value A had overflowed                  |
| Carry         |0000000000100000| Set if value A had overflowed (unsigned)       |
| IsAddress     |0000000010000000| Set if value A was an address                  |
| IsCompatible  |0000000100000000| Set if value A is the same size as B           |

&nbsp;

## Words
| Word name       | Size in bytes   |
|-----------------|----------------:|
| byte            | 1 byte          |
| word            | 2 bytes         |
| dword           | 4 bytes         |
| qword           | 8 bytes         |
| ptrword (32 bit)| 4 bytes         |
| ptrword (64 bit)| 8 bytes         |

&nbsp;

## Segments

| Segment Name | Segment Function | Notes                                                                                           |
|--------------|------------------|-------------------------------------------------------------------------------------------------|
| DATA         | Storing raw data | Attempts to JUMP or in other ways execute from the DATA segment will cause a runtime error.     |
| CODE         | Storing code     | Code is executed from here, CODE segment is read-only.                                          |

&nbsp;

## Instructions
| Id  | OPCode      | Len | Action                                | Notes                                                                           |
|----:|-------------|-----|:-------------------------------------:|---------------------------------------------------------------------------------|
|   0 | POP         | 1   | Pops values off stack (use LDR to get)|                                                                                 |
|   1 | PSH         | 1   | Pushes value to stack                 |                                                                                 |
|   8 | CALL        | 1   | Calls a subroutine                    | For copper subroutines only!                                                    |
|   9 | CALLDPTR    | 1   | Calls a D subroutine/function         | For D function pointers only!                                                   |
|  10 | RET         | 0   | Return to caller                      |                                                                                 |
|  12 | JMP         | 1   | Jump to address                       | You can only jump to CODE segment addresses.                                    |
|  13 | JZ          | 1   | Jump to address if zero               | You can only jump to CODE segment addresses.                                    |
|  14 | JNZ         | 1   | Jump to address if not zero           | You can only jump to CODE segment addresses.                                    |
|  15 | JS          | 1   | Jump to address if sign               | You can only jump to CODE segment addresses.                                    |
|  16 | JNS         | 1   | Jump to address if not sign           | You can only jump to CODE segment addresses.                                    |
|  17 | JC          | 1   | Jump to address if carry              | You can only jump to CODE segment addresses.                                    |
|  18 | JNC         | 1   | Jump to address if not carry          | You can only jump to CODE segment addresses.                                    |
|  19 | JE          | 1   | Jump to address if equal              | You can only jump to CODE segment addresses.                                    |
|  20 | JNE         | 1   | Jump to address if not equal          | You can only jump to CODE segment addresses.                                    |
|  21 | JA          | 1   | Jump to address if above              | You can only jump to CODE segment addresses.                                    |
|  22 | JAE         | 1   | Jump to address if above or equal     | You can only jump to CODE segment addresses.                                    |
|  23 | JB          | 1   | Jump to address if below              | You can only jump to CODE segment addresses.                                    |
|  24 | JBE         | 1   | Jump to address if below or equal     | You can only jump to CODE segment addresses.                                    |
|  25 | CMP         | 2   | Compare X and Y                       | Comparing GP and FP will set Compatible flag to 0.                              |
|  32 | LDR         | 3   | Load from address X to register Y     | Value order is: (register, address, offset (signed))                            |
|  33 | STR         | 3   | Store to address Y from register X    | Value order is: (register, address, offset (signed))                            |
|  43 | MOV         | 2   | Move X to Y                           |                                                                                 |
|  44 | MOVC        | 2   | Move constant X to Y                  |                                                                                 |
|  64 | ADD         | 2   | X + Y                                 | Carry/Overflow flag will be set if overflowing.                                 |
|  65 | ADDS        | 2   | X + Y   (Signed)                      | Carry/Overflow flag will be set if overflowing.                                 |
|  66 | SUB         | 2   | X - Y                                 | Carry/Overflow flag will be set if underflowing.                                |
|  67 | SUBS        | 2   | X - Y   (Signed)                      | Carry/Overflow flag will be set if underflowing.                                |
|  68 | MUL         | 2   | X * Y                                 | Outputs to double the size of registers specified, if needed uses GP0 and GP1.⁰ |
|  69 | MULS        | 2   | X * Y   (Signed)                      | Outputs to double the size of registers specified, if needed uses GP0 and GP1.⁰ |
|  70 | DIV         | 2   | X / Y                                 |                                                                                 |
|  71 | DIVS        | 2   | X / Y   (Signed)                      |                                                                                 |

### Notes
[⁰] Both Carry and Overflow flags will be set if the address space of the value being multipled is overflowed.

&nbsp;

## Temporary Placeholders

Function calls are done via passing the stack as a function parameter to the D function.
This will in the future be replaced by inline assembly-based direct function calls using the compilers and machines native calling conventions.
