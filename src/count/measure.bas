10 print "{clr}{wht}counting for one second..."
20 poke 53265,11:sys 49152:b=peek(251)+256*peek(252):poke 53265,27
30 poke 53265,27:sys 49152:a=peek(251)+256*peek(252)
40 for i=832 to 894:poke i,255:next
50 for i=0 to 7:poke 2040+i,13:poke 53248+2*i,40+28*i:poke 53249+2*i,150:next
60 poke 53269,255:sys 49152:c=peek(251)+256*peek(252)
70 print:print "screen off     ";b
80 print "screen on      ";a
90 print "8 sprites too  ";c
