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

#define STORE_FIXEDVALUE(X) \
        remove_quote(workinfos.fixedvalue,X,sizeof(workinfos.fixedvalue)); \
        workinfos.fixedvaluelen=(unsigned short)strlen(workinfos.fixedvalue);


/* Current working table */
static char table[ID_SIZE];

/* Walker on anon config */
static anon_st *cur = NULL;

/* Walker on json config */
static anon_json_st *jscur = NULL;

/* Walker on truncate config */
static truncate_st *trcur = NULL;

/* Current working DB flat field anon config element */
static anon_st work;

/* Current working anon info */
static anon_base_st workinfos;

/* Current working json anon config element */
static anon_json_st jsonwork;

/* Current working json level */
static int jsonlevel=-1;


%}
%define api.prefix {config_}

%union {
  unsigned short shortval;
  char strval[CONFIG_SIZE];
}

/* 
 * Flex tokens
 */
%token SECRET STATS TABLES YES NO FIXEDNULL FIXED FIXEDQUOTED FIXEDUNQUOTED TEXTHASH EMAILHASH INTHASH TRUNCATE KEY APPENDKEY PREPENDKEY EQ LEFT RIGHT JSONARRAY JSONOBJECT COMMA
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
                } tableaction
tableaction: TRUNCATE {
                  trcur=mymalloc(sizeof(truncate_st));
                  memset(trcur,0,sizeof(truncate_st));
                  mystrcpy(&trcur->key[0],table,ID_SIZE);
                  HASH_ADD_STR(truncate_infos, key, trcur);
               } |
             LEFT fieldlist RIGHT

fieldlist:
  field |
  field fieldlist

field:
  IDENTIFIER { 
    memset(&work,0,sizeof(work));
    memset(&workinfos,0,sizeof(workinfos));
    work.pos =-1 ;
    snprintf(work.key,KEY_SIZE,"%s:%.*s",table,ID_LEN,$1);
    }
  EQ fieldaction {
    cur = mymalloc(sizeof(anon_st));
    memset(cur,0,sizeof(anon_st));
    memcpy(cur,&work,sizeof(anon_st));
    memcpy(&cur->infos,&workinfos,sizeof(anon_base_st));
    HASH_ADD_STR(infos, key, cur);
    jsonlevel=-1;
    //printf("New field\n");
  }

fieldaction:
  FIXEDNULL {
              workinfos.type = AM_FIXEDNULL;
            } |
  FIXED STRING {
                 workinfos.type = AM_FIXED;
                 STORE_FIXEDVALUE($2)
               } |
  FIXEDUNQUOTED STRING {
                 workinfos.type = AM_FIXEDUNQUOTED;
                 STORE_FIXEDVALUE($2)
               } |
  FIXEDQUOTED STRING {
                 workinfos.type = AM_FIXEDQUOTED;
                 STORE_FIXEDVALUE($2)
               } |
  TEXTHASH LENGTH {
                    workinfos.type = AM_TEXTHASH;
                    workinfos.len=(unsigned short)$2;
                  } |
  EMAILHASH STRING LENGTH {
                            workinfos.type = AM_EMAILHASH;
                            workinfos.len = (unsigned short)$3;
                            remove_quote(workinfos.domain,$2,sizeof(workinfos.domain));
                            workinfos.domainlen=(unsigned short)strlen(workinfos.domain);
                            if (workinfos.len + workinfos.domainlen + 1 > MAX_LEN) {
                              config_error("Requested length is too long");
                              exit(EXIT_FAILURE);
                            }
                          } |
  INTHASH LENGTH {
                    workinfos.type = AM_INTHASH;
                    workinfos.len=(unsigned short)$2;
                 } |
  KEY {
        workinfos.type = AM_KEY;
      } |
  APPENDKEY STRING {
                     workinfos.type = AM_APPENDKEY;
                     STORE_FIXEDVALUE($2)
                   } |
  PREPENDKEY STRING {
                     workinfos.type = AM_PREPENDKEY;
                     STORE_FIXEDVALUE($2)
                    } |
  JSONOBJECT LEFT {jsonlevel++;} jsonobjectfields RIGHT {jsonlevel--;} {
                    } |
  JSONARRAY LEFT {jsonlevel++;} jsonarrayelement RIGHT {jsonlevel--;}{
                    }

jsonobjectfields:
  jsonfieldline |
  jsonfieldline COMMA jsonobjectfields

jsonarrayelement:
  fieldaction {
    jscur = mymalloc(sizeof(anon_json_st));
    memset(jscur,0,sizeof(anon_json_st));
    memcpy(&jscur->infos,&workinfos,sizeof(anon_base_st));
    snprintf(jscur->path,KEY_SIZE,"%d-[]",jsonlevel);
    HASH_ADD_STR(cur->json, path, jscur);
  }

jsonfieldline:
  STRING EQ fieldaction {
    jscur = mymalloc(sizeof(anon_json_st));
    memset(jscur,0,sizeof(anon_json_st));
    memcpy(&jscur->infos,&workinfos,sizeof(anon_base_st));
    snprintf(jscur->path,KEY_SIZE,"%d-%s",jsonlevel,$1);
    HASH_ADD_STR(cur->json, path, jscur);
  }
  
%%
