//
//  dict.h
//  ToneBarrier3D
//
//  Created by James Bush on 5/19/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#ifndef dict_h
#define dict_h

#include <stdio.h>
#include "keyval.h"

extern void * dictionary_not_found;

typedef struct keyval{
    char *key;
    void *value;
    keyval *(*keyval_copy)(keyval const *in);
    void (*keyval_free)(keyval *in);
    int (*keyval_matches)(keyval const *in, char const *key);
} keyval;

keyval *keyval_new(char *key, void *value);

typedef struct dictionary
{
   keyval ** pairs;
   int length;
} dictionary;

dictionary * dictionary_new (void);
dictionary * dictionary_copy(dictionary * in);
void dictionary_free(dictionary * in);
void dictionary_add(dictionary * in, char * key, void * value);
void *dictionary_find(dictionary const * in, char const * key);

#endif /* dict_h */
