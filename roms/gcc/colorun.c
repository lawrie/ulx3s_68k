void fill(void)
{
  #define N (1024*8)
  unsigned short int buffer[N];
  for(unsigned short int i = 0; i < N; i++)
    buffer[i] = ~(i<<8) | (i&0xFF);
  unsigned short int *v = (unsigned short int *) 0x10000; // video framebuffer
  for(unsigned short int i = 0; i < N; i++)
    v[i] = 0;
  loop:
  for(unsigned short int i = 0; i < N; i++)
    v[i] = buffer[i]++;
  goto loop;
  stop: goto stop;
}

void __attribute__((noreturn)) main(void)
{
  asm("dc.l 0x20000"); // Set stack to top of RAM
  asm("dc.l fill");    // Set PC to execute fill()
  __builtin_unreachable();
}
