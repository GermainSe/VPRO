

OUTPUT_FORMAT("elf32-littleriscv", "elf32-littleriscv",
	      "elf32-littleriscv")
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY {              
  i_mem (rwx) : ORIGIN = 0x00000000, LENGTH = 0x400000
  comm_mem (rx) : ORIGIN = 0xffffffc4, LENGTH = 0x1000	
}

SECTIONS
{

  .text.trap ALIGN((ORIGIN(i_mem) + 0x00), 64) : AT(ALIGN((ORIGIN(i_mem) + 0x00), 64)) {
    *(.text.trap)
  }
  
  .text.init ALIGN((ORIGIN(i_mem) + 0x80), 64) : AT(ALIGN((ORIGIN(i_mem) + 0x80), 64)) {
    PROVIDE(_ftext = .);
    *(.text.init)
  }
  
  .traphandler  ALIGN((ADDR(.text.init) + SIZEOF(.text.init)), 0x100) : AT(ALIGN((LOADADDR(.text.init) + SIZEOF(.text.init)), 0x100)) {
    *(.traphandler)
  }

  .text ALIGN((ADDR(.traphandler) + SIZEOF(.traphandler)), 0x1000) : AT(ALIGN((LOADADDR(.traphandler) + SIZEOF(.traphandler)), 0x1000)) {
    *(.text)
    PROVIDE(_etext = .);
  }

  .data ALIGN((ADDR(.text) + SIZEOF(.text)), 64) : AT(ALIGN((LOADADDR(.text) + SIZEOF(.text)), 64)) {
    *(.data)
  }
  .data.string ALIGN((ADDR(.data) + SIZEOF(.data)), 64) : AT(ALIGN((LOADADDR(.data) + SIZEOF(.data)), 64)) {
    *(.data.string)
    PROVIDE(_edata = .);
  }

  .bss ALIGN((ADDR(.data.string) + SIZEOF(.data.string)), 64) : AT(ALIGN((LOADADDR(.data.string) + SIZEOF(.data.string)), 64)) {
    *(.bss)
  }
  
  PROVIDE(_end = .);

  .tohost ALIGN((ORIGIN(comm_mem)), 4) : AT(ALIGN((LOADADDR(.bss) + SIZEOF(.bss)), 4)) {
    *(.tohost)
  }

}
