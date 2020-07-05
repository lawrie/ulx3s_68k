MEMORY 
{
    ROM_VECTORS (rx) : ORIGIN = 0x00, LENGTH = 0x10
    ROM_CODE    (rx) : ORIGIN = 0x10, LENGTH = 0x2000
}

SECTIONS
{
    .text.startup :
    {
	*(.text.startup)
    } >ROM_VECTORS

    .text : 
    {
       *(.text)
    } >ROM_CODE
}

OUTPUT_FORMAT(binary)