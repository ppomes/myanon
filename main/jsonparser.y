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
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#include "config.h"
#include "myanon.h"
#include "json.h"

int json_line_nb = 1;

typedef enum {
    JSON_STRING,
    JSON_NUMBER,
    JSON_OBJECT,
    JSON_ARRAY,
    JSON_TRUE,
    JSON_FALSE,
    JSON_NULL
} json_value_type;

struct json_value_st {
    json_value_type type;
    union {
        char *string;
        double number;
        json_object_st *object;
        json_array_st *array;
    } data;
};

struct json_member_st {
    char *key;
    json_value_st *value;
    json_member_st *next;
};

struct json_object_st {
    json_member_st *members;
};

struct json_array_st {
    json_value_st **elements;
    size_t size;
    size_t capacity;
};

static json_value_st *json_root = NULL;

static json_value_st *create_json_value(json_value_type type);
static json_object_st *create_json_object(void);
static json_array_st *create_json_array(void);
static void add_member_to_object(json_object_st *obj, char *key, json_value_st *value);
static void add_element_to_array(json_array_st *arr, json_value_st *value);
static void free_json_value(json_value_st *value);
static void print_json_value(json_value_st *value, int indent);

typedef void (*json_visitor_fn)(const char *path, json_value_st *value, void *context);
static void visit_json_value(json_value_st *value, const char *path, json_visitor_fn visitor, void *context);

/* Utility function - safe strdup using myanon's utilities */
static char *mystrdup(const char *s) {
    if (!s) return NULL;
    size_t len = strlen(s) + 1;
    char *p = mymalloc(len);
    mystrcpy(p, s, len);
    return p;
}

%}

%define api.prefix {json_}

%union {
    char strval[CONFIG_SIZE];
    long intval;
    double dblval;
    json_value_st *jsonval;
    json_object_st *objval;
    json_array_st *arrval;
    json_member_st *memberval;
}

%token LBRACE RBRACE LBRACKET RBRACKET COMMA COLON
%token TRUE_VAL FALSE_VAL NULL_VAL ERROR
%token <strval> STRING
%token <intval> NUMBER_INT
%token <dblval> NUMBER_FLOAT

%type <jsonval> json value object array
%type <objval> object_content
%type <arrval> array_content
%type <memberval> members member

%start json

%%

json:
    value { json_root = $1; $$ = $1; }
    ;

value:
    object      { $$ = $1; }
    | array     { $$ = $1; }
    | STRING    { 
                  $$ = create_json_value(JSON_STRING);
                  $$->data.string = mystrdup($1);
                }
    | NUMBER_INT { 
                  $$ = create_json_value(JSON_NUMBER);
                  $$->data.number = (double)$1;
                }
    | NUMBER_FLOAT { 
                  $$ = create_json_value(JSON_NUMBER);
                  $$->data.number = $1;
                }
    | TRUE_VAL  { $$ = create_json_value(JSON_TRUE); }
    | FALSE_VAL { $$ = create_json_value(JSON_FALSE); }
    | NULL_VAL  { $$ = create_json_value(JSON_NULL); }
    ;

object:
    LBRACE RBRACE { 
        $$ = create_json_value(JSON_OBJECT);
        $$->data.object = create_json_object();
    }
    | LBRACE object_content RBRACE { 
        $$ = create_json_value(JSON_OBJECT);
        $$->data.object = $2;
    }
    ;

object_content:
    members { 
        json_object_st *obj = create_json_object();
        json_member_st *m = $1;
        while (m) {
            add_member_to_object(obj, m->key, m->value);
            json_member_st *next = m->next;
            free(m);
            m = next;
        }
        $$ = obj;
    }
    ;

members:
    member { $$ = $1; }
    | members COMMA member { 
        json_member_st *m = $1;
        while (m->next != NULL) m = m->next;
        m->next = $3;
        $$ = $1;
    }
    ;

member:
    STRING COLON value { 
        $$ = mymalloc(sizeof(json_member_st));
        $$->key = mystrdup($1);
        $$->value = $3;
        $$->next = NULL;
    }
    ;

array:
    LBRACKET RBRACKET { 
        $$ = create_json_value(JSON_ARRAY);
        $$->data.array = create_json_array();
    }
    | LBRACKET array_content RBRACKET { 
        $$ = create_json_value(JSON_ARRAY);
        /* Reverse the array to get correct order */
        size_t i, j;
        for (i = 0, j = $2->size - 1; i < j; i++, j--) {
            json_value_st *temp = $2->elements[i];
            $2->elements[i] = $2->elements[j];
            $2->elements[j] = temp;
        }
        $$->data.array = $2;
    }
    ;

array_content:
    value { 
        json_array_st *arr = create_json_array();
        add_element_to_array(arr, $1);
        $$ = arr;
    }
    | value COMMA array_content { 
        add_element_to_array($3, $1);
        $$ = $3;
    }
    ;

%%

static json_value_st *create_json_value(json_value_type type) {
    json_value_st *val = mymalloc(sizeof(json_value_st));
    val->type = type;
    return val;
}

static json_object_st *create_json_object(void) {
    json_object_st *obj = mymalloc(sizeof(json_object_st));
    obj->members = NULL;
    return obj;
}

static json_array_st *create_json_array(void) {
    json_array_st *arr = mymalloc(sizeof(json_array_st));
    arr->elements = NULL;
    arr->size = 0;
    arr->capacity = 0;
    return arr;
}

static void add_member_to_object(json_object_st *obj, char *key, json_value_st *value) {
    json_member_st *member = mymalloc(sizeof(json_member_st));
    member->key = key;
    member->value = value;
    member->next = NULL;
    
    if (obj->members == NULL) {
        obj->members = member;
    } else {
        json_member_st *last = obj->members;
        while (last->next != NULL) {
            last = last->next;
        }
        last->next = member;
    }
}

static void add_element_to_array(json_array_st *arr, json_value_st *value) {
    if (arr->size >= arr->capacity) {
        size_t new_capacity = arr->capacity == 0 ? 8 : arr->capacity * 2;
        arr->elements = realloc(arr->elements, new_capacity * sizeof(json_value_st *));
        arr->capacity = new_capacity;
    }
    arr->elements[arr->size++] = value;
}

static void free_json_value(json_value_st *value) {
    if (!value) return;
    
    switch (value->type) {
        case JSON_STRING:
            free(value->data.string);
            break;
        case JSON_OBJECT:
            if (value->data.object) {
                json_member_st *m = value->data.object->members;
                while (m) {
                    json_member_st *next = m->next;
                    free(m->key);
                    free_json_value(m->value);
                    free(m);
                    m = next;
                }
                free(value->data.object);
            }
            break;
        case JSON_ARRAY:
            if (value->data.array) {
                for (size_t i = 0; i < value->data.array->size; i++) {
                    free_json_value(value->data.array->elements[i]);
                }
                free(value->data.array->elements);
                free(value->data.array);
            }
            break;
        default:
            break;
    }
    free(value);
}

static void print_json_value(json_value_st *value, int indent) {
    if (!value) return;
    
    switch (value->type) {
        case JSON_STRING:
            printf("\"%s\"", value->data.string);
            break;
        case JSON_NUMBER:
            if (value->data.number == (long)value->data.number) {
                printf("%ld", (long)value->data.number);
            } else {
                printf("%g", value->data.number);
            }
            break;
        case JSON_OBJECT:
            printf("{");
            if (value->data.object && value->data.object->members) {
                printf("\n");
                json_member_st *m = value->data.object->members;
                while (m) {
                    for (int i = 0; i < indent + 2; i++) printf(" ");
                    printf("\"%s\": ", m->key);
                    print_json_value(m->value, indent + 2);
                    if (m->next) printf(",");
                    printf("\n");
                    m = m->next;
                }
                for (int i = 0; i < indent; i++) printf(" ");
            }
            printf("}");
            break;
        case JSON_ARRAY:
            printf("[");
            if (value->data.array && value->data.array->size > 0) {
                printf("\n");
                for (size_t i = 0; i < value->data.array->size; i++) {
                    for (int j = 0; j < indent + 2; j++) printf(" ");
                    print_json_value(value->data.array->elements[i], indent + 2);
                    if (i < value->data.array->size - 1) printf(",");
                    printf("\n");
                }
                for (int i = 0; i < indent; i++) printf(" ");
            }
            printf("]");
            break;
        case JSON_TRUE:
            printf("true");
            break;
        case JSON_FALSE:
            printf("false");
            break;
        case JSON_NULL:
            printf("null");
            break;
    }
}

static void visit_json_value(json_value_st *value, const char *path, json_visitor_fn visitor, void *context) {
    if (!value) return;
    
    visitor(path, value, context);
    
    switch (value->type) {
        case JSON_OBJECT:
            if (value->data.object && value->data.object->members) {
                json_member_st *m = value->data.object->members;
                while (m) {
                    char *new_path = mymalloc(strlen(path) + strlen(m->key) + 2);
                    sprintf(new_path, "%s.%s", path, m->key);
                    visit_json_value(m->value, new_path, visitor, context);
                    free(new_path);
                    m = m->next;
                }
            }
            break;
        case JSON_ARRAY:
            if (value->data.array) {
                for (size_t i = 0; i < value->data.array->size; i++) {
                    char *new_path = mymalloc(strlen(path) + 20);
                    sprintf(new_path, "%s[%zu]", path, i);
                    visit_json_value(value->data.array->elements[i], new_path, visitor, context);
                    free(new_path);
                }
            }
            break;
        default:
            break;
    }
}

static bool json_set_value_at_path(json_value_st *value, const char *path, const char *new_value);
static void json_to_string_internal(json_value_st *value, char **buffer, size_t *size, size_t *pos);

json_value_st *json_parse_string(const char *input) {
    json_root = NULL;
    json_line_nb = 1;
    
    FILE *tmp = tmpfile();
    if (!tmp) return NULL;
    
    fwrite(input, 1, strlen(input), tmp);
    rewind(tmp);
    
    json_in = tmp;
    int ret = json_parse();
    fclose(tmp);
    
    /* Clean up lexer buffers */
    json_lex_destroy();
    
    if (ret != 0) {
        if (json_root) {
            free_json_value(json_root);
            json_root = NULL;
        }
    }
    
    return json_root;
}

void json_replace_value_at_path(json_value_st *root, const char *path, const char *new_value) {
    if (!root || !path || !new_value) return;
    
    /* Skip leading dot if present */
    if (*path == '.') path++;
    
    json_set_value_at_path(root, path, new_value);
}

static json_value_st *json_get_value_at_path(json_value_st *value, const char *path) {
    if (!value || !path) return NULL;
    
    if (*path == '\0') {
        return value;
    }
    
    char segment[256];
    const char *next_path = path;
    size_t i = 0;
    
    while (*next_path && *next_path != '.' && *next_path != '[' && i < sizeof(segment) - 1) {
        segment[i++] = *next_path++;
    }
    segment[i] = '\0';
    
    if (*next_path == '.') next_path++;
    
    if (value->type == JSON_OBJECT && value->data.object) {
        json_member_st *m = value->data.object->members;
        while (m) {
            if (strcmp(m->key, segment) == 0) {
                return json_get_value_at_path(m->value, next_path);
            }
            m = m->next;
        }
    } else if (value->type == JSON_ARRAY && value->data.array && *segment == '[') {
        char *end;
        long index = strtol(segment + 1, &end, 10);
        if (*end == ']' && index >= 0 && (size_t)index < value->data.array->size) {
            return json_get_value_at_path(value->data.array->elements[index], next_path);
        }
    }
    
    return NULL;
}

char *json_get_string_at_path(json_value_st *root, const char *path) {
    if (!root || !path) return NULL;
    
    /* Skip leading dot if present */
    if (*path == '.') path++;
    
    json_value_st *value = json_get_value_at_path(root, path);
    if (value && value->type == JSON_STRING) {
        return value->data.string;
    }
    return NULL;
}

typedef bool (*json_value_processor)(json_value_st *value, void *context);

static bool json_set_value_at_path_with_processor(json_value_st *value, const char *path, 
                                                  json_value_processor processor, void *context);

static bool json_set_value_at_path(json_value_st *value, const char *path, const char *new_value) {
    if (!value || !path || !new_value) return false;
    
    if (*path == '\0') {
        if (value->type == JSON_STRING) {
            free(value->data.string);
            value->data.string = mystrdup(new_value);
            return true;
        }
        return false;
    }
    
    /* Handle array wildcard at start of path */
    if (*path == '[') {
        if (*(path + 1) == ']') {
            /* Wildcard array access [] */
            if (value->type == JSON_ARRAY && value->data.array) {
                bool any_success = false;
                const char *remaining_path = path + 2;
                if (*remaining_path == '.') remaining_path++;
                
                for (size_t i = 0; i < value->data.array->size; i++) {
                    if (json_set_value_at_path(value->data.array->elements[i], remaining_path, new_value)) {
                        any_success = true;
                    }
                }
                return any_success;
            }
        } else {
            /* Specific index [n] */
            char *end;
            long index = strtol(path + 1, &end, 10);
            if (*end == ']' && index >= 0 && (size_t)index < value->data.array->size) {
                const char *remaining_path = end + 1;
                if (*remaining_path == '.') remaining_path++;
                return json_set_value_at_path(value->data.array->elements[index], remaining_path, new_value);
            }
        }
        return false;
    }
    
    char segment[256];
    const char *next_path = path;
    size_t i = 0;
    
    while (*next_path && *next_path != '.' && *next_path != '[' && i < sizeof(segment) - 1) {
        segment[i++] = *next_path++;
    }
    segment[i] = '\0';
    
    if (*next_path == '.') next_path++;
    
    if (value->type == JSON_OBJECT && value->data.object) {
        json_member_st *m = value->data.object->members;
        while (m) {
            if (strcmp(m->key, segment) == 0) {
                /* Check if next_path starts with array access */
                if (*next_path == '[') {
                    if (*(next_path + 1) == ']') {
                        /* Wildcard array access */
                        if (m->value->type == JSON_ARRAY && m->value->data.array) {
                            bool any_success = false;
                            const char *remaining_path = next_path + 2;
                            if (*remaining_path == '.') remaining_path++;
                            
                            for (size_t i = 0; i < m->value->data.array->size; i++) {
                                if (json_set_value_at_path(m->value->data.array->elements[i], remaining_path, new_value)) {
                                    any_success = true;
                                }
                            }
                            return any_success;
                        }
                    } else {
                        /* Specific index */
                        char *end;
                        long index = strtol(next_path + 1, &end, 10);
                        if (*end == ']' && m->value->type == JSON_ARRAY && 
                            m->value->data.array && index >= 0 && 
                            (size_t)index < m->value->data.array->size) {
                            const char *remaining_path = end + 1;
                            if (*remaining_path == '.') remaining_path++;
                            return json_set_value_at_path(m->value->data.array->elements[index], remaining_path, new_value);
                        }
                    }
                    return false;
                } else {
                    return json_set_value_at_path(m->value, next_path, new_value);
                }
            }
            m = m->next;
        }
    }
    
    return false;
}

char *json_to_string(json_value_st *value) {
    if (!value) return NULL;
    
    size_t size = 1024;
    size_t pos = 0;
    char *buffer = mymalloc(size);
    
    json_to_string_internal(value, &buffer, &size, &pos);
    buffer[pos] = '\0';
    
    return buffer;
}

static void json_to_string_internal(json_value_st *value, char **buffer, size_t *size, size_t *pos) {
    if (!value) return;
    
    #define APPEND_STR(str) do { \
        size_t len = strlen(str); \
        while (*pos + len >= *size) { \
            *size *= 2; \
            *buffer = realloc(*buffer, *size); \
        } \
        strcpy(*buffer + *pos, str); \
        *pos += len; \
    } while(0)
    
    #define APPEND_CHAR(c) do { \
        if (*pos + 1 >= *size) { \
            *size *= 2; \
            *buffer = realloc(*buffer, *size); \
        } \
        (*buffer)[(*pos)++] = c; \
    } while(0)
    
    switch (value->type) {
        case JSON_STRING:
            APPEND_CHAR('"');
            /* Strings already contain escape sequences from parsing, just output as-is */
            APPEND_STR(value->data.string);
            APPEND_CHAR('"');
            break;
            
        case JSON_NUMBER:
            {
                char num_str[64];
                if (value->data.number == (long)value->data.number) {
                    snprintf(num_str, sizeof(num_str), "%ld", (long)value->data.number);
                } else {
                    snprintf(num_str, sizeof(num_str), "%g", value->data.number);
                }
                APPEND_STR(num_str);
            }
            break;
            
        case JSON_OBJECT:
            APPEND_CHAR('{');
            if (value->data.object && value->data.object->members) {
                json_member_st *m = value->data.object->members;
                bool first = true;
                while (m) {
                    if (!first) APPEND_CHAR(',');
                    APPEND_CHAR('"');
                    APPEND_STR(m->key);
                    APPEND_STR("\":");
                    json_to_string_internal(m->value, buffer, size, pos);
                    first = false;
                    m = m->next;
                }
            }
            APPEND_CHAR('}');
            break;
            
        case JSON_ARRAY:
            APPEND_CHAR('[');
            if (value->data.array && value->data.array->size > 0) {
                for (size_t i = 0; i < value->data.array->size; i++) {
                    if (i > 0) APPEND_CHAR(',');
                    json_to_string_internal(value->data.array->elements[i], buffer, size, pos);
                }
            }
            APPEND_CHAR(']');
            break;
            
        case JSON_TRUE:
            APPEND_STR("true");
            break;
            
        case JSON_FALSE:
            APPEND_STR("false");
            break;
            
        case JSON_NULL:
            APPEND_STR("null");
            break;
    }
    
    #undef APPEND_STR
    #undef APPEND_CHAR
}

void json_free_value(json_value_st *value) {
    free_json_value(value);
}

bool json_path_has_wildcards(const char *path) {
    if (!path) return false;
    return strstr(path, "[]") != NULL;
}

typedef struct {
    char *value;
    char *new_value;
} json_replacement_st;

static bool json_process_wildcard_values(json_value_st *value, const char *path, 
                                        bool (*processor)(const char *value, void *context),
                                        void *context) {
    if (!value || !path || !processor) return false;
    
    /* Skip leading dot if present */
    if (*path == '.') path++;
    
    if (*path == '\0') {
        if (value->type == JSON_STRING) {
            return processor(value->data.string, context);
        }
        return false;
    }
    
    /* Handle array wildcard at start of path */
    if (*path == '[') {
        if (*(path + 1) == ']') {
            /* Wildcard array access [] */
            if (value->type == JSON_ARRAY && value->data.array) {
                bool any_success = false;
                const char *remaining_path = path + 2;
                if (*remaining_path == '.') remaining_path++;
                
                for (size_t i = 0; i < value->data.array->size; i++) {
                    if (json_process_wildcard_values(value->data.array->elements[i], 
                                                   remaining_path, processor, context)) {
                        any_success = true;
                    }
                }
                return any_success;
            }
        }
        return false;
    }
    
    char segment[256];
    const char *next_path = path;
    size_t i = 0;
    
    while (*next_path && *next_path != '.' && *next_path != '[' && i < sizeof(segment) - 1) {
        segment[i++] = *next_path++;
    }
    segment[i] = '\0';
    
    if (*next_path == '.') next_path++;
    
    if (value->type == JSON_OBJECT && value->data.object) {
        json_member_st *m = value->data.object->members;
        while (m) {
            if (strcmp(m->key, segment) == 0) {
                /* Check if next_path starts with array access */
                if (*next_path == '[') {
                    if (*(next_path + 1) == ']') {
                        /* Wildcard array access */
                        if (m->value->type == JSON_ARRAY && m->value->data.array) {
                            bool any_success = false;
                            const char *remaining_path = next_path + 2;
                            if (*remaining_path == '.') remaining_path++;
                            
                            for (size_t i = 0; i < m->value->data.array->size; i++) {
                                if (json_process_wildcard_values(m->value->data.array->elements[i], 
                                                               remaining_path, processor, context)) {
                                    any_success = true;
                                }
                            }
                            return any_success;
                        }
                    }
                    return false;
                } else {
                    return json_process_wildcard_values(m->value, next_path, processor, context);
                }
            }
            m = m->next;
        }
    }
    
    return false;
}

typedef struct {
    anon_base_st *infos;
    bool is_fixed;
    char *fixed_value;
} wildcard_context_st;

static bool wildcard_anonymize_processor(const char *value, void *context) {
    wildcard_context_st *ctx = (wildcard_context_st *)context;
    
    if (ctx->is_fixed) {
        /* For fixed values, we don't need to process, just mark success */
        return true;
    } else {
        /* For anonymization, we need to process each value */
        anonymized_res_st res = anonymize_token(false, ctx->infos, (char *)value, strlen(value));
        /* The actual replacement happens in the main function */
        return true;
    }
}

typedef struct {
    anon_base_st *infos;
    char *fixed_value;
} json_anonymize_context_st;

static bool json_anonymize_value(json_value_st *value, const char *path, json_anonymize_context_st *ctx);

static bool json_anonymize_at_path(json_value_st *value, const char *path, json_anonymize_context_st *ctx) {
    if (!value || !path || !ctx) return false;
    
    /* Skip leading dot if present */
    if (*path == '.') path++;
    
    if (*path == '\0') {
        if (value->type == JSON_STRING) {
            if (ctx->fixed_value) {
                free(value->data.string);
                value->data.string = mystrdup(ctx->fixed_value);
            } else {
                anonymized_res_st res = anonymize_token(false, ctx->infos, value->data.string, strlen(value->data.string));
                free(value->data.string);
                value->data.string = mymalloc(res.len + 1);
                memcpy(value->data.string, res.data, res.len);
                value->data.string[res.len] = '\0';
            }
            return true;
        }
        return false;
    }
    
    /* Handle array wildcard at start of path */
    if (*path == '[') {
        if (*(path + 1) == ']') {
            /* Wildcard array access [] */
            if (value->type == JSON_ARRAY && value->data.array) {
                bool any_success = false;
                const char *remaining_path = path + 2;
                if (*remaining_path == '.') remaining_path++;
                
                for (size_t i = 0; i < value->data.array->size; i++) {
                    if (json_anonymize_at_path(value->data.array->elements[i], remaining_path, ctx)) {
                        any_success = true;
                    }
                }
                return any_success;
            }
        } else {
            /* Specific index [n] */
            char *end;
            long index = strtol(path + 1, &end, 10);
            if (*end == ']' && value->type == JSON_ARRAY && value->data.array &&
                index >= 0 && (size_t)index < value->data.array->size) {
                const char *remaining_path = end + 1;
                if (*remaining_path == '.') remaining_path++;
                return json_anonymize_at_path(value->data.array->elements[index], remaining_path, ctx);
            }
        }
        return false;
    }
    
    char segment[256];
    const char *next_path = path;
    size_t i = 0;
    
    while (*next_path && *next_path != '.' && *next_path != '[' && i < sizeof(segment) - 1) {
        segment[i++] = *next_path++;
    }
    segment[i] = '\0';
    
    if (*next_path == '.') next_path++;
    
    if (value->type == JSON_OBJECT && value->data.object) {
        json_member_st *m = value->data.object->members;
        while (m) {
            if (strcmp(m->key, segment) == 0) {
                /* Check if next_path starts with array access */
                if (*next_path == '[') {
                    if (*(next_path + 1) == ']') {
                        /* Wildcard array access */
                        if (m->value->type == JSON_ARRAY && m->value->data.array) {
                            bool any_success = false;
                            const char *remaining_path = next_path + 2;
                            if (*remaining_path == '.') remaining_path++;
                            
                            for (size_t i = 0; i < m->value->data.array->size; i++) {
                                if (json_anonymize_at_path(m->value->data.array->elements[i], remaining_path, ctx)) {
                                    any_success = true;
                                }
                            }
                            return any_success;
                        }
                    } else {
                        /* Specific index */
                        char *end;
                        long index = strtol(next_path + 1, &end, 10);
                        if (*end == ']' && m->value->type == JSON_ARRAY && 
                            m->value->data.array && index >= 0 && 
                            (size_t)index < m->value->data.array->size) {
                            const char *remaining_path = end + 1;
                            if (*remaining_path == '.') remaining_path++;
                            return json_anonymize_at_path(m->value->data.array->elements[index], remaining_path, ctx);
                        }
                    }
                    return false;
                } else {
                    return json_anonymize_at_path(m->value, next_path, ctx);
                }
            }
            m = m->next;
        }
    }
    
    return false;
}

void json_anonymize_path(json_value_st *root, const char *path, anon_base_st *infos, char *fixed_value) {
    if (!root || !path) return;
    
    json_anonymize_context_st ctx = {
        .infos = infos,
        .fixed_value = fixed_value
    };
    
    json_anonymize_at_path(root, path, &ctx);
}

void json_error(const char *s) {
    fprintf(stderr, "JSON parse error at line %d: %s\n", json_line_nb, s);
}

extern int json_lex();
extern FILE *json_in;