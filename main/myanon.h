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
#include <limits.h>
#include <regex.h>

#include "uthash.h"
#include "sha2.h"

#include "config.h"




#ifndef EXTERN
#define EXTERN extern
#endif

/*
 * Some constants here
 */

/* Identifier (table or field) len/size */
#define ID_LEN 64
#define ID_SIZE ID_LEN + 1

/* Config file value size */
#define CONFIG_LEN 1026 /* contains up to 1024-char string with begining and ending quote */
#define CONFIG_SIZE CONFIG_LEN + 1

/* Max length from config file */
#define MAX_LEN 32

/* Separator (single char)*/
#define SEPARATOR_LEN 1
#define SEPARATOR_SIZE SEPARATOR_LEN + 1

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
    AM_APPENDKEY,
    AM_PREPENDKEY,
    AM_APPENDINDEX,
    AM_PREPENDINDEX,
    AM_SUBSTRING,
    AM_JSON,
#ifdef HAVE_PYTHON
    AM_PY,
#endif
} anon_type;

/* Actio on table. Currently anonymisation or truncation */
typedef enum table_action_st
{
    ACTION_TRUNCATE,
    ACTION_ANON
} table_action_st;

/* Structure for anonymization info, used by a flat field or a json field */
typedef struct anon_base_st
{
    anon_type type;                /* anonymisation type */
    unsigned short len;            /* requested length from config file */
    char domain[CONFIG_SIZE];      /* Email only: domain */
    unsigned short domainlen;      /* Email only: domain length */
    unsigned long nbhits;          /* Number of times this field has been anonymized */
    char separator[SEPARATOR_SIZE];/* Separator character for multiple separated values */
    char fixedvalue[CONFIG_SIZE];  /* Fixed value */
    unsigned short fixedvaluelen;  /* Length of fixed value */
#ifdef HAVE_PYTHON
    char pydef[CONFIG_SIZE];       /* Python function name used to anonymize */
#endif
} anon_base_st;

/* Structure for anonymization infos for a json field */
typedef struct anon_json_st
{
    char filter[CONFIG_SIZE]; /* json path filter */
    anon_base_st infos;       /* Anon infos */
    UT_hash_handle hh;        /* uthash handle */
} anon_json_st;


/* Structure for anonymization infos of a flat field */
typedef struct anon_field_st
{
    char key[ID_SIZE];  /* key (field name) */
    int pos;            /* field position in table */
    bool quoted;        /* Quoted field ? */
    anon_base_st infos; /* flast Anon infos */
    anon_json_st *json; /* Json anon infos */
    UT_hash_handle hh;  /* uthash handle */
} anon_field_st;

/* Structure for anonymization/truncation infos of a table */
typedef struct anon_table_st
{
    char key[ID_SIZE];      /* table name or regep */
    regex_t *reg_table;     /* regex for table name if regex */
    table_action_st action; /* Truncate or anon */
    anon_field_st *infos;   /* Anon infos */
    UT_hash_handle hh;      /* uthash handle */
} anon_table_st;


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
EXTERN anon_table_st *infos;

/* Hmac secret */
EXTERN char secret[CONFIG_SIZE];
EXTERN unsigned short secretlen;

#ifdef HAVE_PYTHON
/* Python script path */
EXTERN char pypath[PATH_MAX];
/* Python script */
EXTERN char pyscript[CONFIG_SIZE];
#endif

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
char *mysubstr(char *dst, const char *src, size_t dst_size, size_t num_chars);

/* function to anonymize a single field 'token' which length is 'tokenlen'
 * anonymizaton config for this field is *config */
anonymized_res_st anonymize_token(bool quoted, anon_base_st *config, char *token, int tokenlen);

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
extern char *dump_text;         /* Dump last token found */
extern int dump_leng;           /* Dump last token length */

/*
 * Parser line numbers
 */
EXTERN int config_line_nb;       /* Config file line numer */
EXTERN int dump_line_nb;         /* Dump line number */

#endif
