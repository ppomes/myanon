%{
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

#include <stdio.h>
#include <stdbool.h>
#include <string.h>

#include "myanon.h"
#include "configparser.h"
#include "myanon.h"

/* Current working table */
static char table[ID_SIZE];

/* Walker on anon config */
static anon_st *cur = NULL;

/* Current working anon config element */
static anon_st work;


%}
%define api.prefix {config_}

%union {
  unsigned short shortval;
  char strval[CONFIG_SIZE];
}

/* 
 * Flex tokens
 */
%token SECRET STATS TABLES YES NO FIXED TEXTHASH EMAILHASH INTHASH NULLVALUE EQ LEFT RIGHT
%token <strval> STRING IDENTIFIER
%token <shortval> LENGTH

%start directives


%%
directives: directive |
            directive directives

directive:
  secretline |
  statsline |
  tableline

secretline:
  SECRET EQ STRING { 
                    remove_quote(secret,$3,sizeof(secret));
                    secretlen=(unsigned short)strlen(secret);
                   }

statsline:
  STATS EQ YES { stats=true; } |
  STATS EQ NO  { stats=false;}

tableline:
  TABLES EQ LEFT tableslist RIGHT

tableslist: singletable | 
	    singletable tableslist

singletable:
  IDENTIFIER EQ {
                  mystrcpy(table,$1,sizeof(table));
                } LEFT fieldlist RIGHT

fieldlist:
  field |
  field fieldlist

field:
  IDENTIFIER { 
    memset(&work,0,sizeof(work));
    work.pos =-1 ;
    snprintf(work.key,KEY_SIZE,"%s:%s",table,$1);
    }
  EQ action {
    cur = mymalloc(sizeof(anon_st));
    memset(cur,0,sizeof(anon_st));
    memcpy(cur,&work,sizeof(anon_st));
    HASH_ADD_STR(infos, key, cur);
  }

action:
  FIXED STRING {
                 work.type = AM_FIXED;
                 mystrcpy(work.fixedvalue,$2,sizeof(work.fixedvalue));
                 work.fixedvaluelen=(unsigned short)strlen(work.fixedvalue); 
               } |
  TEXTHASH LENGTH {
                    work.type = AM_TEXTHASH;
                    work.len=(unsigned short)$2;
                  } |
  EMAILHASH STRING LENGTH {
                            work.type = AM_EMAILHASH;
                            work.len = (unsigned short)$3;
                            remove_quote(work.domain,$2,sizeof(work.domain));
                            work.domainlen=(unsigned short)strlen(work.domain);
                            if (work.len + work.domainlen + 1 > MAX_LEN) {
                              config_error("Requested length is too long");
                              exit(EXIT_FAILURE);
                            }
                          } |
  INTHASH LENGTH {
                    work.type = AM_INTHASH;
                    work.len=(unsigned short)$2;
                 } |
  NULLVALUE {
        work.type = AM_NULLVALUE;
      }
%%
