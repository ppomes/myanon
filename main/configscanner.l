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


#include "myanon.h"
#include "configparser.h"

/*
 * Usefull macros when using Bison bridge, to return value to Bison
 */
#define COPYSTR mystrcpy(config_lval.strval,config_text,sizeof(config_lval.strval));
#define COPYINT config_lval.shortval=(unsigned short)atoi(config_text);

%}
%option prefix="config_"
%option outfile="lex.yy.c"
%option noyywrap
%option yylineno


%%
secret                  { return SECRET; }
stats                   { return STATS; }
tables                  { return TABLES; }
\'yes\'                 { return YES; }
\'no\'                  { return NO; }
fixed                   { return FIXED; }
texthash                { return TEXTHASH; }
emailhash               { return EMAILHASH; }
inthash                 { return INTHASH; }
nullvalue               { return NULLVALUE; }
=                       { return EQ;}
\{                      { return LEFT;}
\}                      { return RIGHT;}
[0-9]{1,2}              {
                          COPYINT
                          if (config_lval.shortval > MAX_LEN) {
                            config_error("Requested length is too long");
                            exit(EXIT_FAILURE);
                          }
                          return LENGTH;
                        }
\'[^\']{0,64}\'         {
                          COPYSTR
                          return STRING;
                        }
`[^`]{1,64}`            {
                          COPYSTR
                          return IDENTIFIER;
                        }
[ \n]
#.*
.                       {
                          config_error("Syntax error");
                          exit(EXIT_FAILURE);
                        }

%%
