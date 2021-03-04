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

/* Worker on anonymisation info */
static anon_st *cur=NULL;

/* True on first extended insert found for each table */
static bool bfirstinsert;

%}
%define api.prefix {dump_}

/* declare tokens */
%token CREATE_TABLE INSERT_INTO IDENTIFIER TYPE ENGINE
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
     nbytes=snprintf(key,KEY_LEN,"%s:%s",currenttable,dump_text);
     key[nbytes]=0;
     DEBUG_MSG("LOOKING FOR  %s\n",key);
     HASH_FIND_STR(infos,key,cur);
     if (cur != NULL) {
         cur->pos = currentfieldpos;
     }
     currentfieldpos++;
   } TYPE; 

insert_st_list : insert_st
               | insert_st_list insert_st

insert_st : INSERT_INTO VALUES { bfirstinsert=true ; memset(fieldconfig,0,sizeof(fieldconfig));} valueline SEMICOLUMN

valueline: value
           | valueline COMA value

value: LEFTPAR { currentfieldpos =0; }  fieldv RIGHTPAR { bfirstinsert=false ;}

fieldv: singlefield
    | fieldv COMA singlefield

singlefield: VALUE {
      anonymized_res_st res_st;
      char *s;
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
         if (cur->type == AM_FIXED) {
           fwrite(cur->fixedvalue,cur->fixedvaluelen,1,stdout);
         } else { 
           /* not nul terminated !*/
           res_st=anonymize_token(cur,dump_text,dump_leng);
           if (cur->type == AM_INTHASH) {
             fwrite(res_st.data,res_st.len,1,stdout);
           } else {
             fprintf(stdout,"'%.*s'",res_st.len,res_st.data);
           }
         }
      } else {
        fwrite(dump_text,dump_leng,1,stdout);
      }
      currentfieldpos++;
    }

%%
