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

#define EXTERN

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <getopt.h>
#include <sys/time.h>
#include <stdint.h>

#include "config.h"
#include "uthash.h"
#include "sha2.h"
#include "hmac_sha2.h"
#include "myanon.h"

#ifdef HAVE_PYTHON
#include "Python.h"
#endif

/* stdout buffering */
#define STDOUT_BUFFER_SIZE 1048576
static char buffer[STDOUT_BUFFER_SIZE];

#ifdef HAVE_PYTHON
static bool pyinitialized = false;
static PyObject *pModule;

static PyObject* get_secret(PyObject* self, PyObject* args) {
    return PyUnicode_DecodeFSDefault(secret);
}

static PyObject* unescape_sql_string(PyObject* self, PyObject* args) {
    const char *input;
    if (!PyArg_ParseTuple(args, "s", &input)) {
        return NULL;
    }
    
    size_t input_len = strlen(input);
    char *unescaped = mymalloc(input_len + 1);  /* Result will be same size or smaller */
    
    /* Perform unescaping - handle both backslash escaping and double-quote escaping */
    size_t j = 0;
    for (size_t i = 0; i < input_len; i++) {
        if (input[i] == '\\' && i + 1 < input_len) {
            /* Backslash escape sequence */
            if (input[i + 1] == '\'') {
                /* \' becomes ' */
                unescaped[j++] = '\'';
                i++; /* Skip the escaped character */
            } else if (input[i + 1] == '\\') {
                /* \\ becomes \ */
                unescaped[j++] = '\\';
                i++; /* Skip the escaped character */
            } else if (input[i + 1] == '"') {
                /* \" becomes " */
                unescaped[j++] = '"';
                i++; /* Skip the escaped character */
            } else {
                /* Not a recognized escape sequence, keep the backslash */
                unescaped[j++] = input[i];
            }
        } else if (input[i] == '\'' && i + 1 < input_len && input[i + 1] == '\'') {
            /* Double quote '' becomes single quote ' (standard SQL escaping) */
            unescaped[j++] = '\'';
            i++; /* Skip the second quote */
        } else {
            unescaped[j++] = input[i];
        }
    }
    unescaped[j] = '\0';
    
    PyObject *result = PyUnicode_FromString(unescaped);
    free(unescaped);
    return result;
}

static PyObject* escape_sql_string(PyObject* self, PyObject* args) {
    const char *input;
    if (!PyArg_ParseTuple(args, "s", &input)) {
        return NULL;
    }
    
    /* Count chars that need escaping */
    size_t input_len = strlen(input);
    size_t escaped_len = 0;
    for (size_t i = 0; i < input_len; i++) {
        if (input[i] == '\'' || input[i] == '\\') {
            escaped_len += 2;  /* Double the character */
        } else {
            escaped_len++;
        }
    }
    
    /* Allocate output buffer */
    char *escaped = mymalloc(escaped_len + 1);
    
    /* Perform escaping */
    size_t j = 0;
    for (size_t i = 0; i < input_len; i++) {
        if (input[i] == '\'') {
            escaped[j++] = '\'';
            escaped[j++] = '\'';
        } else if (input[i] == '\\') {
            escaped[j++] = '\\';
            escaped[j++] = '\\';
        } else {
            escaped[j++] = input[i];
        }
    }
    escaped[j] = '\0';
    
    PyObject *result = PyUnicode_FromString(escaped);
    free(escaped);
    return result;
}

static PyMethodDef MyanonUtilsMethods[] = {
    {"get_secret", get_secret, METH_NOARGS, "Get HMAC secret"},
    {"unescape_sql_string", unescape_sql_string, METH_VARARGS, "Unescape a SQL string (converts '' to ' and \\\\ to \\)"},
    {"escape_sql_string", escape_sql_string, METH_VARARGS, "Escape a string for SQL (doubles quotes and backslashes)"},
    {NULL, NULL, 0, NULL}
};

static struct PyModuleDef myanon_utils_module = {
    PyModuleDef_HEAD_INIT, "myanon_utils", NULL, -1, MyanonUtilsMethods
};

PyMODINIT_FUNC PyInit_myanon_utils(void) {
    return PyModule_Create(&myanon_utils_module);
}
#endif

void *mymalloc(size_t size)
{
    void *ptr;

    ptr = malloc(size);

    if (NULL == ptr)
    {
        fprintf(stderr, "Memory allocation failed, exiting\n");
        exit(EXIT_FAILURE);
    }

    return ptr;
}

char *mystrcpy(char *dest, const char *src, size_t size)
{
    memset(dest, 0, size);
    strncpy(dest, src, size - 1);
    return dest;
}

static inline int is_escape_char(char c)
{
    return c == '\\';
}

static inline int is_utf8_continuation(unsigned char c)
{
    return (c & 0xC0) == 0x80;
}

static size_t utf8_char_length(unsigned char c)
{
    if ((c & 0x80) == 0)
        return 1;
    if ((c & 0xE0) == 0xC0)
        return 2;
    if ((c & 0xF0) == 0xE0)
        return 3;
    if ((c & 0xF8) == 0xF0)
        return 4;
    return 0; // Invalid UTF-8 start byte
}

static int is_valid_utf8_sequence(const char *src, size_t len)
{
    if (len == 0)
        return 0;
    unsigned char first = (unsigned char)src[0];
    size_t expected_len = utf8_char_length(first);
    if (expected_len == 0 || expected_len > len)
        return 0;
    for (size_t i = 1; i < expected_len; i++)
    {
        if (!is_utf8_continuation((unsigned char)src[i]))
            return 0;
    }
    return 1;
}

char *mysubstr(char *dest, const char *src, size_t dst_size, size_t num_chars)
{
    size_t srccount = 0;
    size_t dstcount = 0;
    size_t copied_chars = 0;
    size_t src_len = strlen(src);
    memset(dest, 0, dst_size);

    while (src[srccount] != '\0' && dstcount < dst_size - 1 && copied_chars < num_chars)
    {
        if (is_escape_char(src[srccount]))
        {
            if (src[srccount + 1] != '\0' && dstcount + 1 < dst_size - 1)
            {
                dest[dstcount++] = src[srccount++];
                dest[dstcount++] = src[srccount++];
                copied_chars++;
            }
            else
            {
                break;
            }
        }
        else
        {
            size_t char_length = utf8_char_length((unsigned char)src[srccount]);
            if (char_length == 0 || srccount + char_length > src_len ||
                !is_valid_utf8_sequence(&src[srccount], char_length))
            {
                break; /* Invalid UTF-8 sequence or end of string */
            }
            if (dstcount + char_length <= dst_size - 1)
            {
                for (size_t i = 0; i < char_length; i++)
                {
                    dest[dstcount++] = src[srccount++];
                }
                copied_chars++;
            }
            else
            {
                break;
            }
        }
    }
    dest[dstcount] = '\0';
    return dest;
}

unsigned long get_ts_in_ms()
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (tv.tv_sec * 1000000 + tv.tv_usec) / 1000;
}

void remove_quote(char *dst, char *src, size_t size)
{
    const char *psrc = src;
    char *pdst = dst;
    size_t src_len = strlen(src);

    memset(dst, 0, size);

    /* Check for leading quote */
    if (src_len > 0 && psrc[0] == '\'')
    {
        psrc++;
        src_len--;
    }

    /* Check for trailing quote */
    if (src_len > 0 && psrc[src_len - 1] == '\'')
    {
        src_len--;
    }

    /* Copy the string without the edge quotes */
    while (src_len > 0 && (pdst - dst < size - 1))
    {
        *pdst++ = *psrc++;
        src_len--;
    }
}

bool config_load(char *filename)
{
    config_in = fopen(filename, "r");

    if (!config_in)
        return false;

    /* The value returned by yyparse is 0 if parsing was successful */
    if (config_parse())
        return false;

    fclose(config_in);

    /* Lex free memory (clean valgrind report) */
    config_lex_destroy();

    return true;
}

void make_readable_hash(const unsigned char *token, unsigned int tokenlen,
                        anonymized_res_st *res_st, char begin, char end)
{
    int i;

    hmac_sha256((const unsigned char *)&secret[0], secretlen, (unsigned char *)token, tokenlen, res_st->data, SHA256_DIGEST_SIZE);

    for (i = 0; i < res_st->len; i++)
    {
        res_st->data[i] = (res_st->data[i] % (end - begin + 1)) + begin;
    }
}

void anonymized_res_free(anonymized_res_st *res)
{
    if (res) {
        free(res);
    }
}

anonymized_res_st *anonymize_token(bool quoted, anon_base_st *config, char *token, int tokenlen,
                                   anon_context_st *ctx)
{
    anonymized_res_st *res_st;
    unsigned long ts_beg, ts_end;
    char *worktoken;
    int worktokenlen;
    bool needfree = false;
#ifdef HAVE_PYTHON
    PyObject *sys_path;
    PyObject *path;
    PyObject *pArgs;
    PyObject *pResult;
    PyObject *pFunc;
#endif

    DEBUG_MSG("ANON_TOKEN for %s - %d - %d\n", token, tokenlen, quoted);

    if (stats)
    {
        ts_beg = get_ts_in_ms();
    }

    if (quoted)
    {
        worktokenlen = tokenlen - 2;
        worktoken = mymalloc(worktokenlen + 1);
        remove_quote(worktoken, token, worktokenlen + 1);
        needfree = true;
    }
    else
    {
        worktoken = token;
        worktokenlen = tokenlen;
    }
    DEBUG_MSG("--WORKTOKEN %s - %d\n", worktoken, worktokenlen);

    /* Pre-allocate result structure - we'll determine size after processing */
    res_st = NULL;

    switch (config->type)
    {
    case AM_FIXEDNULL:
        res_st = mymalloc(sizeof(anonymized_res_st));
        res_st->data = res_st->static_buffer;
        res_st->is_large = false;
        memcpy(res_st->data, "NULL", 4);
        res_st->len = 4;
        res_st->quoting = QUOTE_FORCE_FALSE;
        break;

    case AM_FIXED:
    case AM_FIXEDUNQUOTED:
    case AM_FIXEDQUOTED:
        {
            int datalen = config->fixedvaluelen;
            if (datalen < (int)sizeof(((anonymized_res_st*)0)->static_buffer)) {
                res_st = mymalloc(sizeof(anonymized_res_st));
                res_st->data = res_st->static_buffer;
                res_st->is_large = false;
            } else {
                res_st = mymalloc(sizeof(anonymized_res_st) + datalen + 1);
                res_st->data = (unsigned char *)(res_st + 1);
                res_st->is_large = true;
            }
            memcpy(res_st->data, config->fixedvalue, datalen);
            res_st->len = datalen;
            if (config->type == AM_FIXEDQUOTED)
                res_st->quoting = QUOTE_FORCE_TRUE;
            else if (config->type == AM_FIXEDUNQUOTED)
                res_st->quoting = QUOTE_FORCE_FALSE;
            else
                res_st->quoting = QUOTE_AS_INPUT;
        }
        break;

    case AM_KEY:
        {
            if (worktokenlen < (int)sizeof(((anonymized_res_st*)0)->static_buffer)) {
                res_st = mymalloc(sizeof(anonymized_res_st));
                res_st->data = res_st->static_buffer;
                res_st->is_large = false;
            } else {
                res_st = mymalloc(sizeof(anonymized_res_st) + worktokenlen + 1);
                res_st->data = (unsigned char *)(res_st + 1);
                res_st->is_large = true;
            }
            memcpy(res_st->data, worktoken, worktokenlen);
            res_st->len = worktokenlen;
            res_st->quoting = QUOTE_AS_INPUT;
            if (ctx) {
                mystrcpy(ctx->tablekey, worktoken, ctx->tablekey_size);
            }
        }
        break;

    case AM_APPENDKEY:
        {
            char concatvalue[ID_SIZE];
            int nbcopied = snprintf(concatvalue, ID_SIZE, "%s%s",
                                    config->fixedvalue,
                                    ctx ? ctx->tablekey : "");
            if (nbcopied < (int)sizeof(((anonymized_res_st*)0)->static_buffer)) {
                res_st = mymalloc(sizeof(anonymized_res_st));
                res_st->data = res_st->static_buffer;
                res_st->is_large = false;
            } else {
                res_st = mymalloc(sizeof(anonymized_res_st) + nbcopied + 1);
                res_st->data = (unsigned char *)(res_st + 1);
                res_st->is_large = true;
            }
            memcpy(res_st->data, concatvalue, nbcopied);
            res_st->len = nbcopied;
            res_st->quoting = QUOTE_FORCE_TRUE;
            if (ctx && ctx->tablekey[0] == '\0' && ctx->bfirstinsert) {
                fprintf(stderr, "WARNING! Table %s fields order: for appendkey mode, the key must be defined before the field to anonymize\n",
                        ctx->tablename);
            }
        }
        break;

    case AM_PREPENDKEY:
        {
            char concatvalue[ID_SIZE];
            int nbcopied = snprintf(concatvalue, ID_SIZE, "%s%s",
                                    ctx ? ctx->tablekey : "",
                                    config->fixedvalue);
            if (nbcopied < (int)sizeof(((anonymized_res_st*)0)->static_buffer)) {
                res_st = mymalloc(sizeof(anonymized_res_st));
                res_st->data = res_st->static_buffer;
                res_st->is_large = false;
            } else {
                res_st = mymalloc(sizeof(anonymized_res_st) + nbcopied + 1);
                res_st->data = (unsigned char *)(res_st + 1);
                res_st->is_large = true;
            }
            memcpy(res_st->data, concatvalue, nbcopied);
            res_st->len = nbcopied;
            res_st->quoting = QUOTE_FORCE_TRUE;
            if (ctx && ctx->tablekey[0] == '\0' && ctx->bfirstinsert) {
                fprintf(stderr, "WARNING! Table %s fields order: for prependkey mode, the key must be defined before the field to anonymize\n",
                        ctx->tablename);
            }
        }
        break;

    case AM_APPENDINDEX:
        {
            char concatvalue[ID_SIZE];
            int nbcopied = snprintf(concatvalue, ID_SIZE, "%s%d",
                                    config->fixedvalue,
                                    ctx ? ctx->rowindex : 0);
            if (nbcopied < (int)sizeof(((anonymized_res_st*)0)->static_buffer)) {
                res_st = mymalloc(sizeof(anonymized_res_st));
                res_st->data = res_st->static_buffer;
                res_st->is_large = false;
            } else {
                res_st = mymalloc(sizeof(anonymized_res_st) + nbcopied + 1);
                res_st->data = (unsigned char *)(res_st + 1);
                res_st->is_large = true;
            }
            memcpy(res_st->data, concatvalue, nbcopied);
            res_st->len = nbcopied;
            res_st->quoting = QUOTE_FORCE_TRUE;
        }
        break;

    case AM_PREPENDINDEX:
        {
            char concatvalue[ID_SIZE];
            int nbcopied = snprintf(concatvalue, ID_SIZE, "%d%s",
                                    ctx ? ctx->rowindex : 0,
                                    config->fixedvalue);
            if (nbcopied < (int)sizeof(((anonymized_res_st*)0)->static_buffer)) {
                res_st = mymalloc(sizeof(anonymized_res_st));
                res_st->data = res_st->static_buffer;
                res_st->is_large = false;
            } else {
                res_st = mymalloc(sizeof(anonymized_res_st) + nbcopied + 1);
                res_st->data = (unsigned char *)(res_st + 1);
                res_st->is_large = true;
            }
            memcpy(res_st->data, concatvalue, nbcopied);
            res_st->len = nbcopied;
            res_st->quoting = QUOTE_FORCE_TRUE;
        }
        break;

    case AM_TEXTHASH:
        {
            int hash_len = MIN(SHA256_DIGEST_SIZE, config->len);
            res_st = mymalloc(sizeof(anonymized_res_st));
            res_st->len = hash_len;
            res_st->data = res_st->static_buffer;
            res_st->is_large = false;
            make_readable_hash((unsigned char *)worktoken, worktokenlen, res_st, 'a', 'z');
            res_st->quoting = QUOTE_AS_INPUT;
        }
        break;

    case AM_EMAILHASH:
        {
            int total_len = config->len + 1 + config->domainlen; // anon part + '@' + domain
            res_st = mymalloc(sizeof(anonymized_res_st));
            res_st->len = total_len;
            res_st->data = res_st->static_buffer;
            res_st->is_large = false;
            make_readable_hash((unsigned char *)worktoken, worktokenlen, res_st, 'a', 'z');
            res_st->data[config->len] = '@';
            memcpy(&res_st->data[config->len + 1], config->domain, config->domainlen);
            res_st->quoting = QUOTE_AS_INPUT;
        }
        break;

    case AM_INTHASH:
        {
            int hash_len = MIN(SHA256_DIGEST_SIZE, config->len);
            res_st = mymalloc(sizeof(anonymized_res_st));
            res_st->len = hash_len;
            res_st->data = res_st->static_buffer;
            res_st->is_large = false;
            make_readable_hash((unsigned char *)worktoken, worktokenlen, res_st, '1', '9');
            res_st->quoting = QUOTE_AS_INPUT;
        }
        break;

    case AM_SUBSTRING:
        {
            res_st = mymalloc(sizeof(anonymized_res_st));
            res_st->data = res_st->static_buffer;
            res_st->is_large = false;
            mysubstr((char *)res_st->data, worktoken, sizeof(res_st->static_buffer), config->len);
            res_st->len = strlen((char *)res_st->data);
            res_st->quoting = QUOTE_AS_INPUT;
            DEBUG_MSG("%d, %d, %d, %s\n", worktokenlen, config->len, res_st->len, res_st->data);
        }
        break;

#ifdef HAVE_PYTHON
    case AM_PY:
        if (!pyinitialized)
        {
            PyImport_AppendInittab("myanon_utils", PyInit_myanon_utils);
            Py_Initialize();
            sys_path = PySys_GetObject("path");
            path = PyUnicode_DecodeFSDefault(pypath);
            if (PyList_Append(sys_path, path) != 0)
            {
                PyErr_Print();
                fprintf(stderr, "Failed to add %s to sys.path\n", pypath);
                Py_DECREF(path);
                Py_DECREF(sys_path);
            }
            pModule = PyImport_ImportModule(pyscript);
            if (pModule == NULL)
            {
                PyErr_Print();
            }
            pyinitialized = true;
        }

        if (pModule != NULL)
        {
            pFunc = PyObject_GetAttrString(pModule, config->pydef);
            if (pFunc && PyCallable_Check(pFunc))
            {
                pArgs = Py_BuildValue("(s)", worktoken);
                pResult = PyObject_CallObject(pFunc, pArgs);
                Py_DECREF(pArgs);

                if (pResult != NULL)
                {
                    const char *result = PyUnicode_AsUTF8(pResult);
                    if (result == NULL)
                    {
                        PyErr_Print();
                        Py_DECREF(pResult);
                        /* Return empty result on encoding error */
                        res_st = mymalloc(sizeof(anonymized_res_st));
                        res_st->data = res_st->static_buffer;
                        res_st->is_large = false;
                        res_st->len = 0;
                        res_st->quoting = QUOTE_AS_INPUT;
                        res_st->data[0] = '\0';
                        break;
                    }
                    int result_len = strlen(result);
                    
                    /* Allocate based on result size */
                    if (result_len < sizeof(((anonymized_res_st*)0)->static_buffer)) {
                        /* Use static buffer */
                        res_st = mymalloc(sizeof(anonymized_res_st));
                        res_st->data = res_st->static_buffer;
                        res_st->is_large = false;
                    } else {
                        /* Allocate struct + extra space in one block */
                        res_st = mymalloc(sizeof(anonymized_res_st) + result_len + 1);
                        res_st->data = (unsigned char*)(res_st + 1); /* Point after struct */
                        res_st->is_large = true;
                    }
                    
                    res_st->len = result_len;
                    res_st->quoting = QUOTE_AS_INPUT;
                    memcpy(res_st->data, result, result_len);
                    res_st->data[result_len] = '\0';

                    Py_DECREF(pResult);
                }
                else
                {
                    PyErr_Print();
                    /* Return empty result on error */
                    res_st = mymalloc(sizeof(anonymized_res_st));
                    res_st->data = res_st->static_buffer;
                    res_st->is_large = false;
                    res_st->len = 0;
                    res_st->quoting = QUOTE_AS_INPUT;
                    res_st->data[0] = '\0';
                }
            }
            else
            {
                PyErr_Print();
                /* Return empty result on error */
                res_st = mymalloc(sizeof(anonymized_res_st));
                res_st->data = res_st->static_buffer;
                res_st->is_large = false;
                res_st->len = 0;
                res_st->quoting = QUOTE_AS_INPUT;
                res_st->data[0] = '\0';
            }
            Py_XDECREF(pFunc);
        }
        else
        {
            /* No module - return empty result */
            res_st = mymalloc(sizeof(anonymized_res_st));
            res_st->data = res_st->static_buffer;
            res_st->is_large = false;
            res_st->len = 0;
            res_st->quoting = QUOTE_AS_INPUT;
            res_st->data[0] = '\0';
        }
        break;

#endif

    default:
        /* Unknown type - return empty result */
        res_st = mymalloc(sizeof(anonymized_res_st));
        res_st->data = res_st->static_buffer;
        res_st->is_large = false;
        res_st->len = 0;
        res_st->quoting = QUOTE_AS_INPUT;
        res_st->data[0] = '\0';
        break;
    }

    /* Ensure result is allocated */
    if (!res_st) {
        res_st = mymalloc(sizeof(anonymized_res_st));
        res_st->data = res_st->static_buffer;
        res_st->is_large = false;
        res_st->len = 0;
        res_st->quoting = QUOTE_AS_INPUT;
        res_st->data[0] = '\0';
    }

    if (stats)
    {
        ts_end = get_ts_in_ms();
        anon_time += (ts_end - ts_beg);
    }

    if (needfree)
    {
        free(worktoken);
    }

    config->nbhits++;

    return res_st;
}

void config_error(const char *s)
{
    fprintf(stderr, "Config parsing error at line %d: %s - Unexpected [",
            config_line_nb, s);

    for (const char *p = config_text; *p; p++) {
        unsigned char c = (unsigned char)*p;

        /* Escape common control characters with readable notation */
        if (c == '\n')      fprintf(stderr, "\\n");
        else if (c == '\r') fprintf(stderr, "\\r");
        else if (c == '\t') fprintf(stderr, "\\t");
        else if (c == '\0') fprintf(stderr, "\\0");
        else if (c == '\\') fprintf(stderr, "\\\\");
        // Let everything else pass through
        else
            fputc(c, stderr);
    }

    fprintf(stderr, "]\n");
}

void dump_error(const char *s)
{
    // flush (buffered) stdout and report error
    fflush(stdout);
    fprintf(stderr, "\nDump parsing error at line %d: %s - Unexpected [%s]\n",
            dump_line_nb, s, dump_text);
}

/*
 * Main entry
 */
int main(int argc, char **argv)
{
    int c;
    char *fvalue = NULL;
    anon_table_st *curtable, *tmptable = NULL;
    anon_field_st *curfield, *tmpfield = NULL;
    anon_json_st *jscur, *jstmp = NULL;
    unsigned long ts_beg;
    unsigned long ts_end;

    /* Variable init */
    infos = NULL;
    memset(secret, 0, sizeof(secret));
    secretlen = 0;
#ifdef HAVE_PYTHON
    memset(pypath, 0, sizeof(pypath));
    memset(pyscript, 0, sizeof(pyscript));
#endif
    stats = false;
    debug = false;
    anon_time = 0;
    config_line_nb = 1;
    dump_line_nb = 1;

    /* For stats */
    ts_beg = get_ts_in_ms();

    /* Read command line options */
    static struct option long_options[] = {
        {"help",    no_argument,       NULL, 'h'},
        {"version", no_argument,       NULL, 'v'},
        {NULL,      0,                 NULL,  0 }
    };

    while ((c = getopt_long(argc, argv, "df:hv", long_options, NULL)) != -1)
    {
        switch (c)
        {
        case 'f':
            fvalue = optarg;
            break;
        case 'd':
            debug = true;
            break;
        case 'v':
            fprintf(stdout, "%s %s\n", PACKAGE_NAME, PACKAGE_VERSION);
            exit(EXIT_SUCCESS);
        case 'h':
            fprintf(stdout, "Usage: %s -f config_file [-d]\n", argv[0]);
            fprintf(stdout, "\nOptions:\n");
            fprintf(stdout, "  -f <file>      Configuration file\n");
            fprintf(stdout, "  -d             Debug mode\n");
            fprintf(stdout, "  -v, --version  Show version\n");
            fprintf(stdout, "  -h, --help     Show this help\n");
            exit(EXIT_SUCCESS);
        case '?':
            if (optopt == 'f')
            {
                fprintf(stderr, "Option -%c requires a config file as argument.\n",
                        optopt);
            }
            goto failure;
        }
    }

    /* Activate buffering on stdout */
    if (!debug)
    {
        setvbuf(stdout, &buffer[0], _IOFBF, STDOUT_BUFFER_SIZE);
    }

    if (fvalue == NULL)
    {
        fprintf(stderr, "Usage: %s -f config_file [-d]\n", argv[0]);
        fprintf(stderr, "\nOptions:\n");
        fprintf(stderr, "  -f <file>      Configuration file\n");
        fprintf(stderr, "  -d             Debug mode\n");
        fprintf(stderr, "  -v, --version  Show version\n");
        fprintf(stderr, "  -h, --help     Show this help\n");
        goto failure;
    }

    /* Load config */
    if (!config_load(fvalue))
    {
        fprintf(stderr, "Unable to load config %s\n", fvalue);
        goto failure;
    }

    /* Process dump: the value returned by yyparse is 0 if parsing was successful */
    if (dump_parse())
    {
        goto failure;
    }

    /* Report a warnig on stderr for fields not found */
    for (curtable = infos; curtable != NULL; curtable = curtable->hh.next)
    {
        if (curtable->infos)
        {
            for (curfield = curtable->infos; curfield != NULL; curfield = curfield->hh.next)
            {
                if (curfield->json)
                {
                    for (jscur = curfield->json; jscur != NULL; jscur = jscur->hh.next)
                    {
                        if (0 == jscur->infos.nbhits)
                        {
                            fprintf(stderr, "WARNING! Field %s:%s - JSON path '%s' from config file has not been found in dump. Maybe a config file error?\n", curtable->key, curfield->key, jscur->filter);
                        }
                    }
                }
                if (0 == curfield->infos.nbhits)
                {
                    fprintf(stderr, "WARNING! Field %s:%s from config file has not been found in dump. Maybe a config file error?\n", curtable->key, curfield->key);
                }
            }
        }
    }

    /* Include stats if requested in config file */
    if (stats)
    {
        unsigned long total_anon = 0;
        ts_end = get_ts_in_ms();
        fprintf(stdout, "-- Total execution time: %lu ms\n", ts_end - ts_beg);
        fprintf(stdout, "-- Time spent for anonymization: %lu ms\n", anon_time);
        for (curtable = infos; curtable != NULL; curtable = curtable->hh.next)
        {
            for (curfield = curtable->infos; curfield != NULL; curfield = curfield->hh.next)
            {
                fprintf(stdout, "-- Field %s:%s anonymized %lu time(s)\n",
                        curtable->key, curfield->key, curfield->infos.nbhits);
                total_anon += curfield->infos.nbhits;
            }
        }
        fprintf(stdout, "-- TOTAL Number of anonymization(s): %lu\n", total_anon);
    }

    /* Free Flex memory (clean Valgrind report) */
    dump_lex_destroy();

    /* Free config memory (clean Valgrind report) */
    HASH_ITER(hh, infos, curtable, tmptable)
    {
        HASH_ITER(hh, curtable->infos, curfield, tmpfield)
        {
            HASH_ITER(hh, curfield->json, jscur, jstmp)
            {
                HASH_DEL(curfield->json, jscur);
                free(jscur);
            }
            HASH_DEL(curtable->infos, curfield);
            free(curfield);
        }
        if (curtable->reg_table) {
            regfree(curtable->reg_table);
            free(curtable->reg_table);
        }
        HASH_DEL(infos, curtable);
        free(curtable);
    }

#ifdef HAVE_PYTHON
    if (pyinitialized)
    {
        Py_DECREF(pModule);
        Py_Finalize();
    }

#endif

    exit(EXIT_SUCCESS);

failure:
    exit(EXIT_FAILURE);
}
