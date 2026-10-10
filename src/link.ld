SECTIONS { . = 0x8000E800; .text : { *(.text) *(.data) *(.tail) } /DISCARD/ : { *(.MIPS.abiflags) *(.reginfo) *(.pdr) *(.gnu.attributes) } }
