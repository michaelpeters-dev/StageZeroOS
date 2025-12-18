#include "stdio.h"
#include "x86.h"

void putc(char c)
{
    x86_Video_WriteCharTeletype(c, 0);   /* BIOS teletype output */
}

void puts(const char* str)
{
    while (*str)                        /* until null terminator */
        putc(*str++);                  /* write character */
}
