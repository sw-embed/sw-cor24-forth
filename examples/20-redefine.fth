\ Defining, redefining and forgetting words.
\ A word is defined with : and ; and can be used at once.
: GREET  72 EMIT 105 EMIT 32 EMIT ;   \ prints "Hi "
GREET GREET CR

\ Defining a name again makes a new word that shadows the old one. Words
\ compiled earlier keep calling the definition they were compiled against.
: TWICE  GREET GREET ;
: GREET  72 EMIT 101 EMIT 121 EMIT 32 EMIT ;   \ prints "Hey "
GREET CR                              \ Hey  : the new GREET
TWICE CR                              \ Hi Hi : TWICE still has the old one

\ FORGET removes a word and everything defined after it, so the name can
\ be given a fresh definition. Here it removes the new GREET only.
FORGET GREET
GREET CR                              \ Hi  : back to the first GREET
: GREET  89 EMIT 111 EMIT 33 EMIT 32 EMIT ;   \ prints "Yo! "
GREET TWICE CR                        \ Yo! Hi Hi

\ FORGET of an earlier word takes everything after it with it.
FORGET TWICE
TWICE                                 \ ?  : TWICE is gone, and so is Yo!
GREET CR                              \ Hi  : the first GREET remains
