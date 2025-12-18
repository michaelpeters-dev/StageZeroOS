#pragma once                     /* prevent multiple inclusion */

typedef signed char int8_t;      /* 8-bit signed integer */
typedef unsigned char uint8_t;   /* 8-bit unsigned integer */

typedef signed short int16_t;    /* 16-bit signed integer */
typedef unsigned short uint16_t; /* 16-bit unsigned integer */

typedef signed long int int32_t; /* 32-bit signed integer (Watcom real mode) */
typedef unsigned long int uint32_t; /* 32-bit unsigned integer */

typedef signed long long int int64_t;   /* 64-bit signed integer */
typedef unsigned long long int uint64_t;/* 64-bit unsigned integer */

typedef uint8_t bool;            /* boolean type */

#define false 0                  /* boolean false */
#define true  1                  /* boolean true */