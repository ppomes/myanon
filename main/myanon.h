/*
 * Copyright (C) 2021 Pierre POMES <pierre.pomes@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef MYANON_H
#define MYANON_H

#include <stdbool.h>

#include "uthash.h"
#include "sha2.h"

#ifndef EXTERN
#define EXTERN extern
#endif

/*
 * Some constants here
 */

/* Identifier (table or field) len/size */
#define ID_LEN 64
#define ID_SIZE ID_LEN + 1

/* Key len/size for anon info (format is table:field) */
#define KEY_LEN ID_LEN + 1 + ID_LEN
#define KEY_SIZE KEY_LEN + 1

/* Config file value size */
#define CONFIG_LEN 1026             /* contains up to 1024-char string with begining and ending quote */
#define CONFIG_SIZE CONFIG_LEN + 1

/* Max length from config file */
#define MAX_LEN 32

/* Nice MIN macro */
#define MIN(a, b)                   \
    (                               \
        {                           \
            __typeof__(a) _a = (a); \
            __typeof__(b) _b = (b); \
            _a < _b ? _a : _b;      \
        })

/* Debug macro */
#define DEBUG_MSG(format, ...) \
    if (debug)                 \
        fprintf(stderr, format, ##__VA_ARGS__);

/*
 * Typedefs
 */

/* all types of anonymization types */
typedef enum anon_type
{
    AM_FIXEDNULL = 0,
    AM_FIXED,
    AM_FIXEDQUOTED,
    AM_FIXEDUNQUOTED,
    AM_TEXTHASH,
    AM_EMAILHASH,
    AM_INTHASH,
    AM_KEY,
    AM_CONCATKEY,
} anon_type;

/* Structure for anonymization infos of a single field */
typedef struct anon_st
{
    char key[KEY_SIZE];           /* key is table:field */
    int pos;                      /* field position in table */
    bool quoted;                  /* Quoted field ? */
    anon_type type;               /* anonymisation type */
    unsigned short len;           /* requested length from config file */
    char domain[CONFIG_SIZE];     /* Email only: domain */
    unsigned short domainlen;     /* Email only: domain length */
    unsigned long nbhits;         /* Number of times this field has been anonymized */
    char fixedvalue[CONFIG_SIZE]; /* Fixed value */
    unsigned short fixedvaluelen; /* Length of fixed value */
    UT_hash_handle hh;            /* uthash handle */
} anon_st;

/* Structure for truncation */
typedef struct truncate_st {
    char key[ID_SIZE];            /* key if table name */
    UT_hash_handle hh;            /* uthash handle */
} truncate_st;


/* Structure for anonymization result
   (shared between Bison and C) */
typedef struct anonymized_res_st
{
    unsigned char data[SHA256_DIGEST_SIZE + 1];
    unsigned short len;
} anonymized_res_st;

/*
 * Global variables
 */
/* uthash list for all anonymization fields - contains all anonymization configs */
EXTERN anon_st *infos;

/* uthash list for truncated tables */
EXTERN truncate_st *truncate_infos;


/* Hmac secret */
EXTERN char secret[CONFIG_SIZE];
EXTERN unsigned short secretlen;

/* Generate stats ? */
EXTERN bool stats;

/* Debug mode */
EXTERN bool debug;

/* Time spent to anonymize */
EXTERN unsigned long anon_time;

/*
 * Prototypes
 */

/* some safe malloc/strpcy wrappers */
void *mymalloc(size_t size);
char *mystrcpy(char *dest, const char *src, size_t size);

/* function to anonymize a single field 'token' which length is 'tokenlen'
 * anonymizaton config for this field is *config */
anonymized_res_st anonymize_token(anon_st *config, char *token, int tokenlen);

/* Function to get a timestamp is ms */
unsigned long get_ts_in_ms();

/* Function used to remove quotes from a string 'src'
 * result is generated is 'dst'
 * 'dst' should be allocated by caller */
void remove_quote(char *dst, char *src, size_t size);

/* Main function to load config file */
bool config_load(char *filename);

/*
 * Flex/Bison external symbols - config parsing
 */
int config_lex();                 /* Config Lexer */
int config_parse();               /* Config Parser */
int config_lex_destroy();         /* Config Lexer 'destructor' */
void config_error(const char *s); /* Config parser error function */
extern int config_lineno;         /* Config Line number */
extern char *config_text;         /* Config last token found */
extern int config_leng;           /* Config last token length */
extern FILE *config_in;           /* Config Lexer input */

/*
 * Flex/Bison external symbols - dump parsing
 */
int dump_lex();                 /* Dump Lexer */
int dump_parse();               /* Dump Parser */
int dump_lex_destroy();         /* Dump Lexer 'destructor' */
void dump_error(const char *s); /* Dump parser error function */
extern int dump_lineno;         /* Dump line numner */
extern char *dump_text;         /* Dump last token found */
extern int dump_leng;           /* Dump last token length */

#endif
