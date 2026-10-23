\ Number bases. The interpreter reads numbers, and . prints them, in BASE.
\ HEX and DECIMAL set it to 16 and 10; any base works with BASE !.
255 .                        \ 255
255 HEX . DECIMAL            \ FF
255 2 BASE ! . DECIMAL       \ 11111111
255 8 BASE ! . DECIMAL       \ 377
HEX FF DECIMAL .             \ 255    (FF was read in hex)
8388607 HEX . DECIMAL        \ 7FFFFF (the largest positive 24-bit cell)
BASE @ .                     \ 10     (in any base, the base prints as 10)
