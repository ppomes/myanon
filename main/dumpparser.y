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
#include "uthash.h"

/* Maximum number of fields in a table */
#define MYSQL_MAX_FIELD_PER_TABLE 4096

/* When parsing a table, each field need to be mapped 
   to anonymisation config.
   This is computed on first insert statement */
static anon_st* fieldconfig[MYSQL_MAX_FIELD_PER_TABLE]; 

/* Current table (shared with flex) */
extern char currenttable[];

/* Current key in (table:field) */
static char key[KEY_SIZE];

/* Current field position on table */
static int currentfieldpos;

/* Current kept key field */
static char tablekey[ID_SIZE];

/* Worker on anonymisation info */
static anon_st *cur=NULL;

/* True on first extended insert found for each table */
static bool bfirstinsert;

static void quoted_output_helper (char *s, unsigned short len, bool quoted);

%}
%define api.prefix {dump_}

/* declare tokens */
%token CREATE_TABLE INSERT_INTO IDENTIFIER TYPE QTYPE ENGINE
%token LEFTPAR RIGHTPAR
%token SEMICOLUMN COMA VALUE VALUES


%start dump

%%

dump: tables |
      empty

empty:

tables: table
        | tables table


table: create
      | create insert_st_list

create: CREATE_TABLE { currentfieldpos=0; } LEFTPAR fields RIGHTPAR ENGINE
       
fields: field
      | fields field;

field: IDENTIFIER {
     int nbytes;
     nbytes=snprintf(key,KEY_SIZE,"%s:%s",currenttable,dump_text);
     key[nbytes]=0;
     DEBUG_MSG("LOOKING FOR  %s\n",key);
     HASH_FIND_STR(infos,key,cur);
     if (cur != NULL) {
         cur->pos = currentfieldpos;
     }
     currentfieldpos++;
   } type

type : TYPE { if (cur != NULL) {
                cur->quoted = false;
              }
            }
     | QTYPE { if (cur != NULL) {
                cur->quoted = true;
               }
             }


insert_st_list : insert_st
               | insert_st_list insert_st

insert_st : INSERT_INTO VALUES {
                                 bfirstinsert=true ;
                                 memset(fieldconfig,0,sizeof(fieldconfig));
                               } valueline SEMICOLUMN

valueline: value
           | valueline COMA value

value: LEFTPAR {
                 currentfieldpos =0;
                 memset(tablekey,0,sizeof(tablekey));
               }  fieldv RIGHTPAR {
                                    bfirstinsert=false;
                                  }

fieldv: singlefield
    | fieldv COMA singlefield

singlefield : VALUE {
      anonymized_res_st res_st;
      char *s;
      int nbcopied;
      char concatvalue[ID_SIZE];

      bool found=false;
      if (bfirstinsert) {
        for (cur=infos;cur!=NULL;cur=cur->hh.next) {
          if (memcmp(cur->key,currenttable,strlen(currenttable)) == 0) {
              if (cur->pos == currentfieldpos) {
                  found=true;
                  fieldconfig[currentfieldpos]=cur;
                  break;
              }
          }
        }
      } else {
        if (fieldconfig[currentfieldpos] != NULL) {
          cur = fieldconfig[currentfieldpos];
          found=true;
        }
      }

      if (found) {
        cur->nbhits++;
      }

      /* NULL values should remains NULL
         Skip anonymisation on NULL values */
      if ((found) && (strncmp(dump_text,"NULL",dump_leng))) {
         cur->nbhits++;
         switch(cur->type) {
           case AM_FIXEDNULL:
             quoted_output_helper((char *)"NULL",4,false);
             break;
           case AM_FIXED:
             quoted_output_helper(cur->fixedvalue,cur->fixedvaluelen,cur->quoted);
             break;
           case AM_FIXEDUNQUOTED:
             quoted_output_helper(cur->fixedvalue,cur->fixedvaluelen,false);
             break;
           case AM_FIXEDQUOTED:
             quoted_output_helper(cur->fixedvalue,cur->fixedvaluelen,true);
             break;
           case AM_KEY:
             remove_quote(tablekey,dump_text,sizeof(tablekey));
             quoted_output_helper(dump_text,dump_leng,cur->quoted);
             break;
           case AM_CONCATKEY:
             nbcopied=snprintf(concatvalue,ID_SIZE,"%s%s",cur->fixedvalue,tablekey);
             quoted_output_helper(concatvalue,nbcopied,true);
             break;
           default:
             res_st=anonymize_token(cur,dump_text,dump_leng);
             quoted_output_helper((char *)&res_st.data[0],res_st.len,cur->quoted);
             break;
          }
      } else {
        fwrite(dump_text,dump_leng,1,stdout);
      }
      currentfieldpos++;
    }

%%

/* Helper to output (un)quoted values
   hash values are not nul terminated !*/
static void quoted_output_helper (char *s, unsigned short len, bool quoted)
{
  if (!quoted) {
    fwrite(s,len,1,stdout);
  } else {
    fprintf(stdout,"'%.*s'",len,s);
  }
}
