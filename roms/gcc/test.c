int i;
void main()
{
  asm("dc.l 0");
  asm("dc.l 8");
  for(i = 0; i < 10; i++)
    asm("nop");
  stop: goto stop;
}
