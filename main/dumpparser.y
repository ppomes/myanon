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

#include <stdio.h>
#include <stdbool.h>
#include <string.h>

#include "myanon.h"
#include "uthash.h"
#include "json.h"

/* Maximum number of fields in a table */
#define MYSQL_MAX_FIELD_PER_TABLE 4096

/* When parsing a table, each field need to be mapped 
   to anonymisation config.
   This is computed on first insert statement */
static anon_field_st* fieldconfig[MYSQL_MAX_FIELD_PER_TABLE]; 

/* Current table (shared with flex) */
extern char currenttable[];

/* Current tableconfig (shared with flex) */
extern anon_table_st *currenttableconfig;

/* Current field position on table */
static int currentfieldpos;

/* Current kept key field */
static char tablekey[ID_SIZE];

/* Worker on field info */
static anon_field_st *curfield=NULL;

/* True on first extended insert found for each table */
static bool bfirstinsert;

/* Current row position in current table */
static int rowindex;

static void quoted_output_helper (char *s, unsigned short len, bool quoted);

static void remove_json_backslash(char *dst, const char *src, size_t size);

static void add_json_backslash(char *dst, const char *src, size_t size);

static bool handle_json_anonymization(char *field, int leng, anon_field_st *curfield);

static void handle_separated_values(char *field_text, int field_leng,
                                    anon_field_st *curfield, anon_context_st *ctx);




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

create: CREATE_TABLE {
                       currentfieldpos=0;
                       bfirstinsert=true;
                       rowindex=0;
                       memset(fieldconfig,0,sizeof(fieldconfig));
                     } LEFTPAR fields RIGHTPAR ENGINE
       
fields: field
      | fields field;

field: IDENTIFIER {
    bool found = false;

    HASH_FIND_STR(currenttableconfig->infos, dump_text, curfield);
    found = (curfield != NULL);

    if (found) {
      curfield->pos = currentfieldpos;
      DEBUG_MSG("Found field '%s' at position %d\n", curfield->key, currentfieldpos);
    } else {
      DEBUG_MSG("Field '%s' not found in config at position %d\n", dump_text, currentfieldpos);
    }
    currentfieldpos++;
  } type

type : TYPE { if (curfield != NULL) {
                curfield->quoted = false;
              }
            }
     | QTYPE { if (curfield != NULL) {
                curfield->quoted = true;
               }
             }


insert_st_list : insert_st
               | insert_st_list insert_st

insert_st : INSERT_INTO VALUES valueline SEMICOLUMN

valueline: value
           | valueline COMA value

value: LEFTPAR {
                 currentfieldpos =0;
                 rowindex++;
                 tablekey[0] = '\0';
               }  fieldv RIGHTPAR {
                                    bfirstinsert=false;
                                  }

fieldv: singlefield
    | fieldv COMA singlefield

singlefield : VALUE {
      bool found=false;

      /* Lookup field config (cached after first insert) */
      if (bfirstinsert) {
        for (curfield=currenttableconfig->infos;curfield!=NULL;curfield=curfield->hh.next) {
          if (curfield->pos == currentfieldpos) {
            found=true;
            fieldconfig[currentfieldpos]=curfield;
            break;
          }
        }
      } else {
        if (fieldconfig[currentfieldpos] != NULL) {
          curfield = fieldconfig[currentfieldpos];
          found=true;
        }
      }

      /* NULL values should remain NULL — skip anonymisation on NULL values */
      if ((found) && (strncmp(dump_text,"NULL",dump_leng))) {
        curfield->infos.nbhits++;

        if (curfield->infos.type == AM_JSON) {
          /* JSON anonymization */
          if (!handle_json_anonymization(dump_text, dump_leng, curfield)) {
            out_write(dump_text,dump_leng);
          }
        } else if (curfield->infos.separator[0]) {
          /* Separated values */
          anon_context_st ctx = {
            .tablekey = tablekey,
            .tablekey_size = sizeof(tablekey),
            .rowindex = rowindex,
            .bfirstinsert = bfirstinsert,
            .tablename = currenttable
          };
          handle_separated_values(dump_text, dump_leng, curfield, &ctx);
        } else {
          /* Single value */
          anon_context_st ctx = {
            .tablekey = tablekey,
            .tablekey_size = sizeof(tablekey),
            .rowindex = rowindex,
            .bfirstinsert = bfirstinsert,
            .tablename = currenttable
          };
          anonymized_res_st *res_st = anonymize_token(curfield->quoted, &curfield->infos,
                                                      dump_text, dump_leng, &ctx);
          bool out_quoted;
          switch (res_st->quoting) {
            case QUOTE_FORCE_TRUE:  out_quoted = true; break;
            case QUOTE_FORCE_FALSE: out_quoted = false; break;
            default:                out_quoted = curfield->quoted; break;
          }
          quoted_output_helper((char *)res_st->data, res_st->len, out_quoted);
          anonymized_res_free(res_st);
        }
      } else {
        out_write(dump_text,dump_leng);
      }
      currentfieldpos++;
    }

%%

/* Helper to output (un)quoted values
   hash values are not nul terminated !*/
static void quoted_output_helper (char *s, unsigned short len, bool quoted)
{
  if (!quoted) {
    out_write(s,len);
  } else {
    out_putc('\'');
    out_write(s,len);
    out_putc('\'');
  }
}

static void remove_json_backslash(char *dst, const char *src, size_t size) {
    size_t len = strlen(src);
    size_t j = 0;
    short backslash = 0;
    for (size_t i = 0; i < len; i++) {
        if (src[i] != '\\') {
          if (backslash == 1 ) {
             backslash = 0;
          }
          dst[j++] = src[i];
        }
        else
        {
          backslash++;
          if (backslash % 2 == 0) {
            dst[j++]='\\';
            backslash=0;
          }
        }
    }
    dst[j] = '\0';
}

static void add_json_backslash(char *dst, const char *src, size_t size) {
    size_t len = strlen(src);
    size_t j = 0;

    for (size_t i = 0; i < len && j < size - 1; i++) {
      bool needs_escape = (src[i] == '\"' ||
                           src[i] == '\'' ||
                           src[i] == '\\' ||
                           src[i] == '\b' ||
                           src[i] == '\r' ||
                           src[i] == '\t');
      if (needs_escape) {
        if (j + 2 > size - 1)
          break;
        dst[j++] = '\\';
      }

      dst[j++] = src[i];
    }
    dst[j] = '\0';
}

/* Handle JSON field anonymization.
   Returns true on success, false on parse error (caller outputs original value). */
static bool handle_json_anonymization(char *field, int leng, anon_field_st *curfield) {
    char *unquoted_json_str = mymalloc(leng + 1);
    remove_quote(unquoted_json_str, field, leng + 1);
    char *unbackslash_json_str = mymalloc(leng + 1);
    remove_json_backslash(unbackslash_json_str, unquoted_json_str, leng + 1);
    free(unquoted_json_str);

    DEBUG_MSG("Json before: %s - after: %s\n", field, unbackslash_json_str);

    json_value_st *parsed_json = json_parse_string(unbackslash_json_str);
    if (!parsed_json) {
        fprintf(stderr, "WARNING! Table/field %s: Unable to parse json field '%s' at line %d, skip anonymization\n",
                curfield->key, unbackslash_json_str, dump_line_nb);
        free(unquoted_json_str);
        free(unbackslash_json_str);
        return false;
    }

    /* Loop over json rules and replace */
    anon_json_st *jscur;
    for (jscur = curfield->json; jscur != NULL; jscur = jscur->hh.next) {
        if (json_path_has_wildcards(jscur->filter)) {
            json_anonymize_path(parsed_json, jscur->filter, &jscur->infos,
                              jscur->infos.type == AM_FIXED ? jscur->infos.fixedvalue : NULL);
        } else {
            char newvalue_buf[CONFIG_SIZE];
            char *newvalue;

            char *current_value = json_get_string_at_path(parsed_json, jscur->filter);
            if (!current_value) continue;

            switch (jscur->infos.type) {
                case AM_FIXED:
                    newvalue = jscur->infos.fixedvalue;
                    break;
                default:
                {
                    anonymized_res_st *res_st = anonymize_token(false, &jscur->infos,
                                                                current_value, strlen(current_value), NULL);
                    memcpy(newvalue_buf, res_st->data, res_st->len);
                    newvalue_buf[res_st->len] = '\0';
                    newvalue = newvalue_buf;
                    anonymized_res_free(res_st);
                    break;
                }
            }

            json_replace_value_at_path(parsed_json, jscur->filter, newvalue);
        }
        jscur->infos.nbhits++;
    }

    char *resultstr = json_to_string(parsed_json);
    size_t resultstr_len = strlen(resultstr);
    char *newjsonbackslash_str = mymalloc(resultstr_len * 2 + 1);
    add_json_backslash(newjsonbackslash_str, resultstr, resultstr_len * 2 + 1);
    quoted_output_helper(newjsonbackslash_str, strlen(newjsonbackslash_str), true);

    free(resultstr);
    json_free_value(parsed_json);
    free(unbackslash_json_str);
    free(newjsonbackslash_str);

    return true;
}

/* Handle separated values (fields with a separator character).
   Splits the field by separator and anonymizes each sub-value. */
static void handle_separated_values(char *field_text, int field_leng,
                                    anon_field_st *curfield, anon_context_st *ctx) {
    char *worktext;

    /* Handle quoting if present */
    if (curfield->quoted) {
        worktext = mymalloc(field_leng + 1);
        remove_quote(worktext, field_text, field_leng + 1);
    } else {
        /* strtok modifies its input, so always work on a copy */
        worktext = mymalloc(field_leng + 1);
        memcpy(worktext, field_text, field_leng);
        worktext[field_leng] = '\0';
    }

    /* First extraction */
    char *field = strtok(worktext, curfield->infos.separator);
    if (!field) {
        fprintf(stderr, "WARNING! Table/field %s: Unable to parse separated field '%s' at line %d, skip anonymization",
                curfield->key, field_text, dump_line_nb);
        out_write(field_text, field_leng);
        free(worktext);
        return;
    }

    out_putc('\''); /* Opening quote */

    bool first = true;
    while (field) {
        if (!first) {
            out_putc(curfield->infos.separator[0]);
        }
        first = false;

        int leng = strlen(field);
        anonymized_res_st *res_st = anonymize_token(false, &curfield->infos, field, leng, ctx);

        bool out_quoted;
        switch (res_st->quoting) {
            case QUOTE_FORCE_TRUE:  out_quoted = true; break;
            case QUOTE_FORCE_FALSE: out_quoted = false; break;
            default:                out_quoted = false; break;
        }
        quoted_output_helper((char *)res_st->data, res_st->len, out_quoted);
        anonymized_res_free(res_st);

        field = strtok(NULL, curfield->infos.separator);
    }

    out_putc('\''); /* Closing quote */

    free(worktext);
}



