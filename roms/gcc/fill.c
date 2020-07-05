void main()
{
  asm("dc.l 0x20000"); // Set stack to top of RAM
  asm("dc.l 8");       // Set PC to start
  unsigned short int *v = (unsigned short int *) 0x10000; // video framebuffer
  for(unsigned short int i = 0; i < 255; i++)
  {
    v[0] = v[i] = (i<<8) | i;
    asm("nop");
  }
  stop: goto stop;
}
