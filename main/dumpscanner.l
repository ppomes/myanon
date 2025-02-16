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

#include "dumpparser.h"
#include "myanon.h"
#include "uthash.h"

/* Used to duplicate flex input to stdout */
#define DUPOUT fwrite(dump_text,dump_leng,1,stdout);

/* Current table */
char currenttable[ID_SIZE];

/* current config element */
anon_table_st *currenttableconfig;

/* Increase Flex buffers */
#undef YY_READ_BUF_SIZE
#undef YY_BUF_SIZE
#define YY_READ_BUF_SIZE 65536
#define YY_BUF_SIZE 131072

/* Set current working table according to flex token
   flex_tolen contains "CREATE TABLE `xxxx`"

   Find matching config */

static void set_working_table() {
  char *beg,*end;
  static anon_table_st *walker=NULL;
  bool bfound=false;

  memset(currenttable,0,sizeof(currenttable));
  beg=strchr(dump_text,'`');
  if (beg) {
    end=strchr(beg+1,'`');

    if (end) {
      memcpy(currenttable,beg,(end-beg+1));

      DEBUG_MSG("FOUND TABLE %s\n",currenttable);
    }
  }

  currenttableconfig=NULL;

  for (walker=infos;walker!=NULL; walker=walker->hh.next) {
    if (walker->reg_table) {
      if (regexec(walker->reg_table, currenttable, 0, NULL, 0) == 0) {
        bfound=true;
        break;
      }
    } else {
      if (strncmp(walker->key,currenttable,strlen(currenttable)) == 0) {
        bfound=true;
        break;
      }
    }
  }

  if (bfound) {
    currenttableconfig=walker;
  }
}


    
%}
%option prefix="dump_"
%option outfile="lex.yy.c"
%option noyywrap
%option full
%option pointer

%x ST_TABLE ST_TRUNCATE ST_VALUES

%%
^CREATE\ TABLE\ `[^`]+`           { DUPOUT
                                    set_working_table();

                                    if (currenttableconfig) {
                                      if (currenttableconfig->action == ACTION_ANON) {
                                        BEGIN(ST_TABLE);
                                        DEBUG_MSG("\nENTERING STATE ST_TABLE")
                                        return CREATE_TABLE;
                                      }

                                      if (currenttableconfig->action == ACTION_TRUNCATE) {
                                        BEGIN(ST_TRUNCATE);
                                        DEBUG_MSG("\nENTERING STATE ST_TRUNCATE")
                                      }
                                    }
                                  }

^(INSERT|REPLACE)\ (\ IGNORE\ )?\INTO\ `[^`]+`(?:\ \([^\)]+\))?  { DUPOUT
                                    if (currenttableconfig) {
                                      BEGIN(ST_VALUES);
                                      DEBUG_MSG("\nENTERING STATE ST_VALUES")
                                      return INSERT_INTO;
                                    }
                                  }
\n                                { DUPOUT dump_line_nb++; }
.                                 { DUPOUT }

<ST_TRUNCATE>^CREATE\ TABLE\ `[^`]+`  { DUPOUT
                                        BEGIN(INITIAL);
                                        DEBUG_MSG("\nENTERING STATE INITIAL")

                                        set_working_table();

                                        if (currenttableconfig) {
                                          if (currenttableconfig->action == ACTION_ANON) {
                                            BEGIN(ST_TABLE);
                                            DEBUG_MSG("\nENTERING STATE ST_TABLE")
                                            return CREATE_TABLE;
                                          }

                                          if (currenttableconfig->action == ACTION_TRUNCATE) {
                                            BEGIN(ST_TRUNCATE);
                                            DEBUG_MSG("\nENTERING STATE ST_TRUNCATE")
                                          }
                                        }
                                      }

<ST_TRUNCATE>^(INSERT|REPLACE).*  { /* In truncate mode, skip statements */}
<ST_TRUNCATE>\n                   { DUPOUT dump_line_nb++; }
<ST_TRUNCATE>.                    { DUPOUT }


<ST_TABLE>`[^`]+`                       { DUPOUT return IDENTIFIER ;}
<ST_TABLE>VALUES                        { DUPOUT return VALUES ;}
<ST_TABLE>\(                            { DUPOUT return LEFTPAR; }
<ST_TABLE>\)                            { DUPOUT return RIGHTPAR; }
<ST_TABLE>;                             { DUPOUT return SEMICOLUMN; }
<ST_TABLE>,                             { DUPOUT return COMA; }
<ST_TABLE>(tiny|small|medium|big)?int.* { DUPOUT return TYPE; }
<ST_TABLE>double.*                      { DUPOUT return TYPE; }
<ST_TABLE>decimal.*                     { DUPOUT return TYPE; }
<ST_TABLE>float.*                       { DUPOUT return TYPE; }
<ST_TABLE>(tiny|medium|long)?text.*     { DUPOUT return QTYPE; }
<ST_TABLE>enum.*                        { DUPOUT return QTYPE; }
<ST_TABLE>char\(.*                      { DUPOUT return QTYPE; }
<ST_TABLE>varchar\(.*                   { DUPOUT return QTYPE; }
<ST_TABLE>binary\(.*                    { DUPOUT return TYPE; }
<ST_TABLE>varbinary\(.*                 { DUPOUT return TYPE; }
<ST_TABLE>(tiny|medium|long)?blob.*     { DUPOUT return QTYPE; }
<ST_TABLE>date.*                        { DUPOUT return QTYPE; }
<ST_TABLE>year.*                        { DUPOUT return TYPE; }
<ST_TABLE>time.*                        { DUPOUT return QTYPE; }
<ST_TABLE>bit.*                         { DUPOUT return TYPE; }
<ST_TABLE>json.*                        { DUPOUT return QTYPE; }
<ST_TABLE>set.*                         { DUPOUT return QTYPE; }
<ST_TABLE>point.*                       { DUPOUT return TYPE; }
<ST_TABLE>geometry.*                    { DUPOUT return TYPE; }
<ST_TABLE>PRIMARY\ KEY.*                { DUPOUT }
<ST_TABLE>UNIQUE\ KEY.*                 { DUPOUT }
<ST_TABLE>FULLTEXT\ KEY.*               { DUPOUT }
<ST_TABLE>KEY.*                         { DUPOUT }
<ST_TABLE>CONSTRAINT.*                  { DUPOUT }
<ST_TABLE>DELIMITER.*                   { DUPOUT }
<ST_TABLE>[ ]                           { DUPOUT }
<ST_TABLE>\n                            { DUPOUT dump_line_nb++; }
<ST_TABLE>ENGINE.*                      { BEGIN(INITIAL);
                                          DEBUG_MSG("\nENTERING STATE INITIAL")
                                          DUPOUT
                                          return ENGINE;
                                        }
<ST_TABLE>.                             { /* Parsing error - report error and exit now */
                                          dump_error("Unable to read table definition");
                                          exit(EXIT_FAILURE);
                                        }


<ST_VALUES>VALUES                           { DUPOUT return VALUES ;}
<ST_VALUES>`[^`]+`                          { DUPOUT return IDENTIFIER ;}
<ST_VALUES>\(                               { DUPOUT return LEFTPAR; }
<ST_VALUES>\)                               { DUPOUT return RIGHTPAR; }
<ST_VALUES>;                                { DUPOUT return SEMICOLUMN; }
<ST_VALUES>,                                { DUPOUT return COMA; }
<ST_VALUES>NULL                             { return VALUE; }
<ST_VALUES>0x[0-9a-fA-F]+                   { return VALUE; }
<ST_VALUES>_binary\ '(\\.|[^'\\])*'         { return VALUE; }
<ST_VALUES>'(\\.|[^'\\])*'                  { return VALUE; }
<ST_VALUES>[0-9\-\.e]+                      { return VALUE; }
<ST_VALUES>[ ]                              { DUPOUT }
<ST_VALUES>\n                               { DUPOUT dump_line_nb++;}
<ST_VALUES>^(INSERT|REPLACE)\ (\ IGNORE\ )?\INTO\ `[^`]+`(?:\ \([^\)]+\))? { DUPOUT
                                              if (currenttableconfig) {
                                                return INSERT_INTO;
                                              }
                                            }
<ST_VALUES>.                                { BEGIN(INITIAL);
                                              DEBUG_MSG("\nENTERING STATE INITIAL")
                                              DUPOUT
                                            }

%%
