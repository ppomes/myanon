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

#define EXTERN

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <getopt.h>
#include <sys/time.h>

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
#endif

void *mymalloc(size_t size)
{
    void *ptr;

    ptr = malloc(size);

    if (NULL == ptr)
    {
        fprintf(stderr, "Memory allocatiom failed, exiting\n");
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

anonymized_res_st anonymize_token(bool quoted, anon_base_st *config, char *token, int tokenlen)
{
    anonymized_res_st res_st;
    unsigned long ts_beg, ts_end;
    char *worktoken;
    int worktokenlen;
    bool needfree = false;
#ifdef HAVE_PYTHON
    PyObject *pName;
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

    switch (config->type)
    {
    case AM_TEXTHASH:
        res_st.len = MIN(SHA256_DIGEST_SIZE, config->len);
        make_readable_hash((unsigned char *)worktoken, worktokenlen, &res_st, 'a', 'z');
        break;

    case AM_EMAILHASH:
        res_st.len = config->len + 1 + config->domainlen; // anon part + '@' + domain
        make_readable_hash((unsigned char *)worktoken, worktokenlen, &res_st, 'a', 'z');
        res_st.data[config->len] = '@';
        memcpy(&res_st.data[config->len + 1], config->domain, config->domainlen);
        break;

    case AM_INTHASH:
        res_st.len = MIN(SHA256_DIGEST_SIZE, config->len);
        make_readable_hash((unsigned char *)worktoken, worktokenlen, &res_st, '1', '9');
        break;

#ifdef HAVE_PYTHON
    case AM_PY:
        if (!pyinitialized)
        {
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

        res_st.len = 0;
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
                    res_st.len = strlen(result);
                    mystrcpy((char *)&(res_st.data[0]), result, sizeof(res_st.data));
                    Py_DECREF(pResult);
                }
                else
                {
                    PyErr_Print();
                }
            }
            else
            {
                PyErr_Print();
            }
            Py_XDECREF(pFunc);
        }
        break;

#endif

    default:
        break;
    }

    res_st.data[res_st.len] = '\0';

    if (stats)
    {
        ts_end = get_ts_in_ms();

        anon_time += (ts_end - ts_beg);
    }

    if (needfree)
    {
        free(worktoken);
    }

    return res_st;
}

void config_error(const char *s)
{
    fprintf(stderr, "Config parsing error at line %d: %s - Unexpected [%s]\n",
            config_lineno, s, config_text);
}

void dump_error(const char *s)
{
    // flush (buffered) stdout and report error
    fflush(stdout);
    fprintf(stderr, "\nDump parsing error at line %d: %s - Unexpected [%s]\n",
            dump_lineno, s, dump_text);
}

/*
 * Main entry
 */
int main(int argc, char **argv)
{
    int c;
    char *fvalue = NULL;
    anon_st *cur, *tmp = NULL;
    truncate_st *trcur, *trtmp = NULL;
#ifdef HAVE_JQ
    anon_json_st *jscur, *jstmp = NULL;
#endif
    unsigned long ts_beg;
    unsigned long ts_end;

    /* Variable init */
    infos = NULL;
    truncate_infos = NULL;
    memset(secret, 0, sizeof(secret));
    secretlen = 0;
#ifdef HAVE_PYTHON
    memset(pypath, 0, sizeof(pypath));
    memset(pyscript, 0, sizeof(pyscript));
#endif
    stats = false;
    debug = false;
    anon_time = 0;

    /* For stats */
    ts_beg = get_ts_in_ms();

    /* Read command line options */
    while ((c = getopt(argc, argv, "df:")) != -1)
    {
        switch (c)
        {
        case 'f':
            fvalue = optarg;
            break;
        case 'd':
            debug = true;
            break;
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
    for (cur = infos; cur != NULL; cur = cur->hh.next)
    {
#ifdef HAVE_JQ
        if (cur->json)
        {
            for (jscur = cur->json; jscur != NULL; jscur = jscur->hh.next)
            {
                if (0 == jscur->infos.nbhits)
                {
                    fprintf(stderr, "WARNING! Field %s - JQ filter '%s' from config file has not been found in dump. Maybe a config file error?\n", cur->key, jscur->filter);
                }
            }
        }
#endif
        if (0 == cur->infos.nbhits)
        {
            fprintf(stderr, "WARNING! Field %s from config file has not been found in dump. Maybe a config file error?\n", cur->key);
        }
    }

    /* Include stats if requested in config file */
    if (stats)
    {
        unsigned long total_anon = 0;
        ts_end = get_ts_in_ms();
        fprintf(stdout, "-- Total execution time: %lu ms\n", ts_end - ts_beg);
        fprintf(stdout, "-- Time spent for anonymization: %lu ms\n", anon_time);
        for (cur = infos; cur != NULL; cur = cur->hh.next)
        {
            fprintf(stdout, "-- Field %s anonymized %lu time(s)\n",
                    cur->key, cur->infos.nbhits);
            total_anon += cur->infos.nbhits;
        }
        fprintf(stdout, "-- TOTAL Number of anonymization(s): %lu\n", total_anon);
    }

    /* Free Flex memory (clean Valgrind report) */
    dump_lex_destroy();

    /* Free config memory (clean Valgrind report) */
    HASH_ITER(hh, infos, cur, tmp)
    {
#ifdef HAVE_JQ
        HASH_ITER(hh, infos->json, jscur, jstmp)
        {
            jq_teardown(&(jscur->jq_state));
            HASH_DEL(infos->json, jscur);
            free(jscur);
        }
#endif
        HASH_DEL(infos, cur);
        free(cur);
    }

    HASH_ITER(hh, truncate_infos, trcur, trtmp)
    {
        HASH_DEL(truncate_infos, trcur);
        free(trcur);
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
