void main()
{
  asm("dc.l 0x20000"); // Set stack to top of RAM
  asm("dc.l 8");       // Set PC to start
  short unsigned int *v = (short unsigned int *) 0x10000; // video framebuffer
  for(short unsigned int i = 0; i < 256; i++)
  {
    v[0] = v[i] = ((i&0xFF)<<8) | (i&0xFF);
    asm("nop");
  }
  stop: goto stop;
}
