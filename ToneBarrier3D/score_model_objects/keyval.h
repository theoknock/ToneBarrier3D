//
//  keyval.h
//  ToneBarrier3D
//
//  Created by James Bush on 5/19/20.
//  Copyright © 2020 James Bush. All rights reserved.
//

#ifndef keyval_h
#define keyval_h

#include <stdio.h>

typedef struct keyval
{
   char * key;
   void * value;
} keyval;

keyval * keyval_new(char * key, void * value);
keyval * keyval_copy(keyval const * in);
void keyval_free(keyval * in);
int keyval_matches(keyval const * in, char const * key);

#endif /* keyval_h */
