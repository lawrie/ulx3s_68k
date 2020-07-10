volatile unsigned char *ACIAC = (unsigned char *) 0x600001;
volatile unsigned char *ACIAD = (unsigned char *) 0x600003;
#define RDRF 0
#define TDRE 1

void delay(int d)
{
  for(int i = 0; i < d; i++)
    asm("nop");
}

void serial_init(void)
{
  *ACIAC = 3; // reset ACIA
  delay(10000);
  *ACIAC = 0x15; // RTS enabled 9600
}

void cout(char *a)
{
  for(; *a != 0; a++)
  {
    while( (*ACIAC & (1<<TDRE)) == 0);
    *ACIAD = *a;
  }
}

void hello(void)
{
  char *line = "* Hello\n\r";
  char c = 0;
  serial_init();
  for(;;)
  {
    line[0] = '0' + (7 & c++);
    cout(line);
    delay(100000);
  } 
}

void __attribute__((noreturn)) main(void)
{
  asm("dc.l 0x20000"); // Set stack to top of RAM
  asm("dc.l hello");    // Set PC to execute fill()
  __builtin_unreachable();
}
