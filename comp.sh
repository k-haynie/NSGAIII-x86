nasm -f elf32 nsga.s -o nsga.o && gcc -nostartfiles -m32 -o nsga nsga.o && ./nsga