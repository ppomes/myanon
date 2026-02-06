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
#include <ctype.h>
#include <regex.h>


#include "config.h"
#include "myanon.h"
#include "configparser.h"
#include "myanon.h"

#define STORE_FIXEDVALUE(X) \
        remove_quote(basework.fixedvalue,X,sizeof(basework.fixedvalue)); \
        basework.fixedvaluelen=(unsigned short)strlen(basework.fixedvalue);


/* Current regex compilation return code */
static int reg_ret;

/* Current regex error msg */
static char reg_msg[CONFIG_SIZE];

/* Current working table config */
static anon_table_st *currenttableconfig;

/* Current working field config */
static anon_field_st *curfield;

/* Walker on json config */
static anon_json_st *jscur = NULL;

/* Current working anon info (may be used for flat or json field) */
static anon_base_st basework;

/* Current json anon working list */
static anon_json_st *jslist=NULL;

/* Small function used to validate json path */
static bool is_valid_json_path(const char *path);


%}
%define api.prefix {config_}

%union {
  unsigned short shortval;
  char strval[CONFIG_SIZE];
}

/* 
 * Flex tokens
 */
%token SECRET STATS TABLES YES NO FIXEDNULL FIXED FIXEDQUOTED FIXEDUNQUOTED TEXTHASH EMAILHASH INTHASH TRUNCATE KEY APPENDKEY PREPENDKEY APPENDINDEX PREPENDINDEX EQ LEFT RIGHT PYPATH PYSCRIPT PYDEF JSON PATH SEPARATEDBY SUBSTRING REGEX
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
                    fprintf(stderr, "Python support disabled, ignoring pypath directive at line %d\n",config_line_nb);
                    #endif 
                   }

pyscriptline:
  PYSCRIPT EQ STRING {
                      #ifdef HAVE_PYTHON
                      remove_quote(pyscript,$3,sizeof(secret));
                      #else
                      fprintf(stderr, "Python support disabled, ignoring pyscript directive at line %d\n",config_line_nb);
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
                  currenttableconfig = mymalloc(sizeof(anon_table_st));
                  memset(currenttableconfig,0,sizeof(anon_table_st));
                  currenttableconfig->action=ACTION_ANON;
                  mystrcpy(currenttableconfig->key,$1,sizeof(currenttableconfig->key));
                } tableaction |
  REGEX IDENTIFIER EQ {
                     currenttableconfig = mymalloc(sizeof(anon_table_st));
                     memset(currenttableconfig,0,sizeof(anon_table_st));
                     currenttableconfig->action=ACTION_ANON;
                     currenttableconfig->reg_table=mymalloc(sizeof(regex_t));
                     memset(currenttableconfig->reg_table,0,sizeof(regex_t));
                     mystrcpy(currenttableconfig->key,$2,sizeof(currenttableconfig->key));
                     reg_ret=regcomp(currenttableconfig->reg_table, currenttableconfig->key, REG_EXTENDED);
                     if (reg_ret) {
                        regerror(reg_ret, currenttableconfig->reg_table, reg_msg, sizeof(reg_msg));
                        fprintf(stderr, "Unable to compile regex '%s' at line %d: %s\n", currenttableconfig->key, config_line_nb, reg_msg);
                        exit(EXIT_FAILURE);
                     }
                   } tableaction
tableaction: TRUNCATE {
                  currenttableconfig->action=ACTION_TRUNCATE;
                  anon_table_st *dup = NULL;
                  HASH_FIND_STR(infos, currenttableconfig->key, dup);
                  if (dup) {
                      fprintf(stderr, "Error: table %s is defined more than once in config file at line %d\n", currenttableconfig->key, config_line_nb);
                      exit(EXIT_FAILURE);
                  }
                  HASH_ADD_STR(infos, key, currenttableconfig);
               } |
             LEFT fieldlist RIGHT {
                  currenttableconfig->action=ACTION_ANON;
                  anon_table_st *dup = NULL;
                  HASH_FIND_STR(infos, currenttableconfig->key, dup);
                  if (dup) {
                      fprintf(stderr, "Error: table %s is defined more than once in config file at line %d\n", currenttableconfig->key, config_line_nb);
                      exit(EXIT_FAILURE);
                  }
                  HASH_ADD_STR(infos, key, currenttableconfig);
               }

fieldlist:
  field |
  field fieldlist

field:
  IDENTIFIER {
    curfield=mymalloc(sizeof(anon_field_st));
    memset(curfield,0,sizeof(anon_field_st));
    memset(&basework,0,sizeof(basework));
    curfield->pos = -1;
    jslist=NULL;
    mystrcpy(curfield->key,$1,sizeof(curfield->key));
    }
  EQ fieldaction {
    curfield->json=jslist;
    memcpy(&curfield->infos,&basework,sizeof(anon_base_st));
    anon_field_st *dupf = NULL;
    HASH_FIND_STR(currenttableconfig->infos, curfield->key, dupf);
    if (dupf) {
        fprintf(stderr, "Error: field %s in table %s is defined more than once in config file at line %d\n", curfield->key, currenttableconfig->key, config_line_nb);
        exit(EXIT_FAILURE);
    }
    HASH_ADD_STR(currenttableconfig->infos, key, curfield);
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
  substring |
  substring separated |
  key |
  appendkey |
  prependkey |
  appendindex |
  prependindex |
  pydef |
  json |

fixednull :
  FIXEDNULL {
              basework.type = AM_FIXEDNULL;
            }

fixedstring :
  FIXED STRING {
                 basework.type = AM_FIXED;
                 STORE_FIXEDVALUE($2)
               }

fixedunquotedstring:
  FIXEDUNQUOTED STRING {
                 basework.type = AM_FIXEDUNQUOTED;
                 STORE_FIXEDVALUE($2)
               }

fixedquotedstring:
  FIXEDQUOTED STRING {
                 basework.type = AM_FIXEDQUOTED;
                 STORE_FIXEDVALUE($2)
               }

texthash:
  TEXTHASH LENGTH {
                    basework.type = AM_TEXTHASH;
                    basework.len=(unsigned short)$2;
                  }

emailhash:
  EMAILHASH STRING LENGTH {
                            basework.type = AM_EMAILHASH;
                            basework.len = (unsigned short)$3;
                            remove_quote(basework.domain,$2,sizeof(basework.domain));
                            basework.domainlen=(unsigned short)strlen(basework.domain);
                            if (basework.len + basework.domainlen + 1 > MAX_LEN) {
                              config_error("Requested length is too long");
                              exit(EXIT_FAILURE);
                            }
                          }

inthash:
  INTHASH LENGTH {
                    basework.type = AM_INTHASH;
                    basework.len=(unsigned short)$2;
                 }

substring:
  SUBSTRING LENGTH {
                    basework.type = AM_SUBSTRING;
                    basework.len=(unsigned short)$2;
                  }

key:
  KEY {
        basework.type = AM_KEY;
      }

appendkey:
  APPENDKEY STRING {
                     basework.type = AM_APPENDKEY;
                     STORE_FIXEDVALUE($2)
                   }
prependkey:
  PREPENDKEY STRING {
                     basework.type = AM_PREPENDKEY;
                     STORE_FIXEDVALUE($2)
                    }
appendindex:
  APPENDINDEX STRING {
                     basework.type = AM_APPENDINDEX;
                     STORE_FIXEDVALUE($2)
                   }
prependindex:
  PREPENDINDEX STRING {
                     basework.type = AM_PREPENDINDEX;
                     STORE_FIXEDVALUE($2)
                    }

pydef:
  PYDEF STRING {
                 #ifdef HAVE_PYTHON
                 basework.type = AM_PY;
                 remove_quote(basework.pydef,$2,sizeof(basework.pydef));
                 #else
                 fprintf(stderr, "Python support disabled, ignoring pydef directive at line %d\n",config_line_nb);
                 #endif
               }

json:
  JSON LEFT jsonlines RIGHT {
                     basework.type = AM_JSON;
                    }

separated:
  SEPARATEDBY STRING {
                       /* The separator must be a single character, surrounded by quotes */
                       if (strlen($2) > 3) {
                         fprintf(stderr, "Warning: separator is only one char, keeping first char\n");
                       }
                       basework.separator[0]=($2)[1];
                     }

jsonlines:
  jsonline |
  jsonline jsonlines

jsonline:
  PATH STRING EQ jsonaction {
    jscur = mymalloc(sizeof(anon_json_st));
    memset(jscur,0,sizeof(anon_json_st));
    memcpy(&jscur->infos,&basework,sizeof(anon_base_st));
    remove_quote(jscur->filter,$2,CONFIG_SIZE);
    /* Add leading dot if not present */
    if (jscur->filter[0] != '.') {
      char temp[CONFIG_SIZE];
      mystrcpy(temp, jscur->filter, CONFIG_SIZE);
      jscur->filter[0] = '.';
      mystrcpy(&jscur->filter[1], temp, CONFIG_SIZE-1);
    }
    if (!is_valid_json_path(jscur->filter)) {
      fprintf(stderr, "Invalid json path '%s', ignoring it\n",jscur->filter);
    }
    else
    {
      HASH_ADD_STR(jslist, filter, jscur);
    }
  }

jsonaction:
  fixedstring |
  inthash |
  texthash |
  emailhash |
  pydef
%%

static bool is_valid_json_path(const char *path) {
  if (!path || !*path) return false;

  while (*path) {
    if (!((isalnum(*path) || *path == '_' || *path == '.'))) {
      if (*path == '[') {
        path++;
        if (*path != ']') {
          return false;
        }
      }
      else
      {
        return false;
      }
    }
    path++;
  }

  return true;
}
