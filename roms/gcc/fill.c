void main()
{
  asm("dc.l 0");
  asm("dc.l 8");
  int *v = (int *) 0x10000; // video framebuffer
  for(int i = 128; i < 1024; i++)
  {
    v[0] = i;
    v[i] = i;
    asm("nop");
  }
  stop: goto stop;
}
