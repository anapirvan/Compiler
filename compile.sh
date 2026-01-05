#!/bin/bash

flex limbaj.l
bison -d -Wcounterexamples limbaj.y 
g++ lex.yy.c limbaj.tab.c 
./a.out in.txt