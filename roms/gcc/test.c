void main()
{
  asm("dc.l 0");
  asm("dc.l 8");
  for(int i = 0; i < 10; i++)
    asm("nop");
  stop: goto stop;
}
