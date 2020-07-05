void fill(void)
{
  unsigned short int *v = (unsigned short int *) 0x10000; // video framebuffer
  const short unsigned int N = 1024;
  for(unsigned short int i = 0; i < N; i++)
    v[i] = 0;
  for(unsigned short int i = 0; i < N; i++)
    v[i] = (i<<8) | (i&0xFF);
  stop: goto stop;
}

void main(void)
{
  asm("dc.l 0x20000"); // Set stack to top of RAM
  asm("dc.l 8");       // Set PC to execute fill()
  fill();
}
