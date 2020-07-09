./asmx68 -s9 -e -w test.asm -o test.s9
srec_cat test.s9 -o test.bin -binary
python3 tomem.py test.bin >test.mem

