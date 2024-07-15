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
#ifdef HAVE_JQ
#include <jv.h>
#include <jq.h>
#endif


#include "config.h"
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

#ifdef HAVE_JQ
/* Walker on json config */
static anon_json_st *jscur = NULL;
#endif

/* Walker on truncate config */
static truncate_st *trcur = NULL;

/* Current working DB flat field anon config element */
static anon_st work;

/* Current working anon info */
static anon_base_st workinfos;

#ifdef HAVE_JQ
/* Current json anon working list */
static anon_json_st *jslist=NULL;
#endif

#ifdef HAVE_JQ
/* Current working json anon config element */
static anon_json_st jsonwork;
#endif


%}
%define api.prefix {config_}

%union {
  unsigned short shortval;
  char strval[CONFIG_SIZE];
}

/* 
 * Flex tokens
 */
%token SECRET STATS TABLES YES NO FIXEDNULL FIXED FIXEDQUOTED FIXEDUNQUOTED TEXTHASH EMAILHASH INTHASH TRUNCATE KEY APPENDKEY PREPENDKEY EQ LEFT RIGHT PYPATH PYSCRIPT PYDEF JSON PATH SEPARATEDBY
%token <strval> STRING IDENTIFIER
%token <shortval> LENGTH

%start directives


%%
directives: directive |
            directive directives

directive:
  secretline   |
  statsline    |
  pypathline   |
  pyscriptline |
  tableline

secretline:
  SECRET EQ STRING { 
                    remove_quote(secret,$3,sizeof(secret));
                    secretlen=(unsigned short)strlen(secret);
                   }

pypathline:
  PYPATH EQ STRING {
                    #ifdef HAVE_PYTHON
                    char absolutepath[PATH_MAX];
                    memset(absolutepath,0,sizeof(absolutepath));
                    remove_quote(pypath,$3,sizeof(secret));
                    if (pypath[0] != '/') {
                       if (realpath(pypath,absolutepath) == NULL) {
                          fprintf(stderr, "Unable to get absolute Python path for %s\n",pypath);
                       } else {
                          mystrcpy(pypath,absolutepath,sizeof(pypath));
                       }
                    }
                    #else
                    fprintf(stderr, "Python support disabled, ignoring pypath directive at line %d\n",config_lineno);
                    #endif 
                   }

pyscriptline:
  PYSCRIPT EQ STRING {
                      #ifdef HAVE_PYTHON
                      remove_quote(pyscript,$3,sizeof(secret));
                      #else
                      fprintf(stderr, "Python support disabled, ignoring pyscript directive at line %d\n",config_lineno);
                      #endif
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
    #ifdef HAVE_JQ
    jslist=NULL;
    #endif
    snprintf(work.key,KEY_SIZE,"%s:%.*s",table,ID_LEN,$1);
    }
  EQ fieldaction {
    cur = mymalloc(sizeof(anon_st));
    memset(cur,0,sizeof(anon_st));
    memcpy(cur,&work,sizeof(anon_st));
    memcpy(&cur->infos,&workinfos,sizeof(anon_base_st));
    #ifdef HAVE_JQ
    cur->json=jslist;
    #endif
    HASH_ADD_STR(infos, key, cur);
  }

fieldaction:
  fixednull |
  fixednull separated |
  fixedstring |
  fixedstring separated |
  fixedunquotedstring |
  fixedunquotedstring separated |
  fixedquotedstring |
  fixedquotedstring separated |
  texthash |
  texthash separated |
  emailhash |
  emailhash separated |
  inthash |
  inthash separated |
  key |
  appendkey |
  prependkey |
  pydef |
  json |

fixednull :
  FIXEDNULL {
              workinfos.type = AM_FIXEDNULL;
            }

fixedstring :
  FIXED STRING {
                 workinfos.type = AM_FIXED;
                 STORE_FIXEDVALUE($2)
               }

fixedunquotedstring:
  FIXEDUNQUOTED STRING {
                 workinfos.type = AM_FIXEDUNQUOTED;
                 STORE_FIXEDVALUE($2)
               }

fixedquotedstring:
  FIXEDQUOTED STRING {
                 workinfos.type = AM_FIXEDQUOTED;
                 STORE_FIXEDVALUE($2)
               }

texthash:
  TEXTHASH LENGTH {
                    workinfos.type = AM_TEXTHASH;
                    workinfos.len=(unsigned short)$2;
                  }

emailhash:
  EMAILHASH STRING LENGTH {
                            workinfos.type = AM_EMAILHASH;
                            workinfos.len = (unsigned short)$3;
                            remove_quote(workinfos.domain,$2,sizeof(workinfos.domain));
                            workinfos.domainlen=(unsigned short)strlen(workinfos.domain);
                            if (workinfos.len + workinfos.domainlen + 1 > MAX_LEN) {
                              config_error("Requested length is too long");
                              exit(EXIT_FAILURE);
                            }
                          }

inthash:
  INTHASH LENGTH {
                    workinfos.type = AM_INTHASH;
                    workinfos.len=(unsigned short)$2;
                 }
key:
  KEY {
        workinfos.type = AM_KEY;
      }

appendkey:
  APPENDKEY STRING {
                     workinfos.type = AM_APPENDKEY;
                     STORE_FIXEDVALUE($2)
                   }
prependkey:
  PREPENDKEY STRING {
                     workinfos.type = AM_PREPENDKEY;
                     STORE_FIXEDVALUE($2)
                    }
pydef:
  PYDEF STRING {
                 #ifdef HAVE_PYTHON
                 workinfos.type = AM_PY;
                 remove_quote(workinfos.pydef,$2,sizeof(workinfos.pydef));
                 #else
                 fprintf(stderr, "Python support disabled, ignoring pydef directive at line %d\n",config_lineno);
                 #endif
               }

json:
  JSON LEFT jsonlines RIGHT {
                     #ifdef HAVE_JQ
                     workinfos.type = AM_JSON;
                     #else
                     fprintf(stderr, "JQ support disabled, ignoring json directive at line %d\n",config_lineno);
                     #endif
                    }

separated:
  SEPARATEDBY STRING {
                       /* The separator must be a single character, surrounded by quotes */
                       if (strlen($2) > 3) {
                         fprintf(stderr, "Warning: separator is only one char, keeping first char\n");
                       }
                       workinfos.separator[0]=($2)[1];
                     }

jsonlines:
  jsonline |
  jsonline jsonlines

jsonline:
  PATH STRING EQ jsonaction {
    #ifdef HAVE_JQ
    jscur = mymalloc(sizeof(anon_json_st));
    memset(jscur,0,sizeof(anon_json_st));
    memcpy(&jscur->infos,&workinfos,sizeof(anon_base_st));
    jscur->filter[0]='.';
    remove_quote(&(jscur->filter[1]),$2,CONFIG_SIZE-1);
    jscur->jq_state=jq_init();
    if (jq_compile(jscur->jq_state,jscur->filter) == 0) {
      fprintf(stderr, "Warning cannot compile jq filter '%s', ignoring it\n",jscur->filter);
      jq_teardown(&jscur->jq_state);
    } else {
      HASH_ADD_STR(jslist, filter, jscur);
    }
    #endif
  }

jsonaction:
  fixedstring |
  inthash |
  texthash |
  emailhash
%%
