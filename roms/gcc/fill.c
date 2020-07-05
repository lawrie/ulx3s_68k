void main()
{
  asm("dc.l 0x20000"); // Set stack to top of RAM
  asm("dc.l 8");       // Set PC to start
  int *v = (int *) 0x10000; // video framebuffer
  for(int i = 0; i < 256; i++)
  {
    v[0] = i;
    v[i] = i;
    asm("nop");
  }
  stop: goto stop;
}
