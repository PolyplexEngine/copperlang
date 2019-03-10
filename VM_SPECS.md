# Virtual Machine Specifications (Work in Progress)
The Copper VM is a register based VM, following some X86 architectural decisions.

## Registers

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
| STCK          | Stack Pointer       | Mostly modified using pop/push    |
| FLG           | Flag Register       | Flags not accesible directly      |
| IC            | Instruction Counter | The instruction counter           |

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
| IsFP          |0100000000000000| Set if value A was a floating point value      |


## Words
| Word name       | Size in bytes   |
|-----------------|----------------:|
| byte            | 1 byte          |
| word            | 2 bytes         |
| dword           | 4 bytes         |
| qword           | 8 bytes         |
| ptrword (32 bit)| 4 bytes         |
| ptrword (64 bit)| 8 bytes         |

## Segments

| Segment Name | Segment Function | Notes                                                                                           |
|--------------|------------------|-------------------------------------------------------------------------------------------------|
| DATA         | Storing raw data | Attempts to JUMP or in other ways execute from the DATA segment will cause a runtime error. |
| CODE         | Storing code     | Code is executed from here, CODE segment is read-only.                                          |

## Instructions
To be written


## Temporary Placeholders

Function calls are done via passing the stack as a function parameter to the D function.
This will in the future be replaced by inline assembly-based direct function calls using the compilers and machines native calling conventions.