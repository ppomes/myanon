%{
/*
 * Copyright (C) 2021-2026 Pierre POMES <pierre.pomes@gmail.com>
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

#include <string.h>
#include <stdlib.h>
#include "myanon.h"
#include "json.h"
#include "jsonparser.h"

void json_error(const char *s);

#define COPYDBL json_lval.dblval=strtod(json_text,NULL);
#define COPYINT json_lval.intval=strtol(json_text,NULL,10);

extern int json_line_nb;

/* Growable buffer for the JSON string being scanned. JSON string values
   have no length limit: a fixed CONFIG_SIZE buffer used to truncate them
   silently. On the closing quote the buffer is handed over to the parser,
   which owns and frees it. */
static char *strbuf = NULL;
static size_t strbuf_len = 0;
static size_t strbuf_cap = 0;

static void strbuf_append(const char *s, size_t n)
{
    if (strbuf_len + n + 1 > strbuf_cap) {
        size_t newcap = strbuf_cap ? strbuf_cap : 64;
        while (strbuf_len + n + 1 > newcap)
            newcap *= 2;
        char *p = realloc(strbuf, newcap);
        if (!p) {
            fprintf(stderr, "Memory allocation failed, exiting\n");
            exit(EXIT_FAILURE);
        }
        strbuf = p;
        strbuf_cap = newcap;
    }
    memcpy(strbuf + strbuf_len, s, n);
    strbuf_len += n;
    strbuf[strbuf_len] = '\0';
}

static void strbuf_reset(void)
{
    strbuf_len = 0;
    strbuf_append("", 0);
}

static char *strbuf_take(void)
{
    char *s = strbuf;
    strbuf = NULL;
    strbuf_len = strbuf_cap = 0;
    return s;
}

/* Free a string left unterminated by a malformed JSON value */
void json_scanner_cleanup(void)
{
    free(strbuf);
    strbuf = NULL;
    strbuf_len = strbuf_cap = 0;
}

%}

%option prefix="json_"
%option outfile="jsonscanner.c"
%option noyywrap

DIGIT    [0-9]
DIGIT1   [1-9]
E        [eE][+-]?{DIGIT}+

%x IN_STRING

%%

\{                      { return LBRACE; }
\}                      { return RBRACE; }
\[                      { return LBRACKET; }
\]                      { return RBRACKET; }
,                       { return COMMA; }
:                       { return COLON; }

true                    { return TRUE_VAL; }
false                   { return FALSE_VAL; }
null                    { return NULL_VAL; }

-?{DIGIT1}{DIGIT}*      { COPYINT; return NUMBER_INT; }
-?{DIGIT}+              { COPYINT; return NUMBER_INT; }

-?{DIGIT}+"."{DIGIT}*{E}?    { COPYDBL; return NUMBER_FLOAT; }
-?{DIGIT}*"."{DIGIT}+{E}?    { COPYDBL; return NUMBER_FLOAT; }
-?{DIGIT}+{E}                { COPYDBL; return NUMBER_FLOAT; }

\"                      { BEGIN(IN_STRING); strbuf_reset(); }

<IN_STRING>{
    \"                  { BEGIN(INITIAL); json_lval.strval = strbuf_take(); return STRING; }
    \\.                 { /* Escape sequences are copied literally */
                          strbuf_append(json_text, (size_t)json_leng);
                        }
    [^\\\"\n]+          { strbuf_append(json_text, (size_t)json_leng); }
    \n                  { json_line_nb++; strbuf_append(json_text, (size_t)json_leng); }
}

[ \t\r]+                ;
\n                      { json_line_nb++; }

.                       { 
                          json_error("Unexpected character");
                          return ERROR;
                        }

%%