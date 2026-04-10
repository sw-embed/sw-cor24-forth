#!/usr/bin/env bash
# demo.sh — Run sw-cor24-forth Forth demos
# Usage:
#   ./demo.sh           Run automated demo (non-interactive)
#   ./demo.sh repl      Start interactive REPL
#   ./demo.sh test      Run test suite and check results

set -euo pipefail
FORTH="forth.s"
RUN="cor24-run --run $FORTH --speed 0"

case "${1:-demo}" in
  repl)
    echo "=== sw-cor24-forth REPL ==="
    echo "Type Forth commands. Ctrl-C to exit."
    echo ""
    cor24-run --run "$FORTH" --terminal --echo --speed 0
    ;;

  test)
    echo "=== sw-cor24-forth Test Suite ==="
    PASS=0
    FAIL=0

    check() {
      local desc="$1" input="$2" expect="$3"
      local raw result
      raw=$($RUN -u "$input" -n 5000000 2>&1 | grep "^UART output:" -A 20 | tr '\n' ' ')
      # Extract interpreter output: everything after "42 " (boot DOT test)
      result=$(echo "$raw" | sed-rs -e 's/.*UART output: //' -e 's/Executed.*//' -e 's/  */ /g' -e 's/^ //;s/ $//')
      expect=$(echo "$expect" | sed-rs -e 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [ "$result" = "$expect" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
      else
        echo "  FAIL: $desc"
        echo "    expected: '$expect'"
        echo "    got:      '$result'"
        FAIL=$((FAIL + 1))
      fi
    }

    echo "--- Arithmetic ---"
    check "1 ."           '1 .\n'           '1 ok'
    check "2 3 + ."       '2 3 + .\n'       '5 ok'
    check "-7 ."          '-7 .\n'          '-7 ok'
    check "10 3 - ."      '10 3 - .\n'      '7 ok'

    echo "--- Stack ops ---"
    check "DEPTH (empty)"  'DEPTH .\n'       '0 ok'
    check "1 2 3 DEPTH ."  '1 2 3 DEPTH .\n' '3 ok'
    check "1 2 3 .S"       '1 2 3 .S\n'      '<3> 1 2 3 ok'
    check "DUP"            '5 DUP + .\n'     '10 ok'
    check "SWAP"           '1 2 SWAP . .\n'  '1 2 ok'
    check "OVER"           '1 2 OVER . . .\n' '1 2 1 ok'
    check "DROP"           '1 2 DROP .\n'    '1 ok'

    echo "--- Number base ---"
    check "HEX FF ."       'HEX FF . DECIMAL\n'  'FF ok'
    check "HEX A ."        'HEX A . DECIMAL\n'   'A ok'
    check "DECIMAL 255 ."  '255 .\n'              '255 ok'

    echo "--- LED ---"
    echo "  SKIP: LED! (hardware register, not verifiable in cor24-run)"

    echo "--- Stack stability ---"
    check ".S repeated"     '1 2 3 .S\n.S\n.S\nDEPTH .\n'  '<3> 1 2 3 ok <3> 1 2 3 ok <3> 1 2 3 ok 3 ok'
    check "no REPL leak"    'DEPTH .\nDEPTH .\nDEPTH .\n'   '0 ok 0 ok 0 ok'
    check "no WORDS leak"   'WORDS\nDEPTH .\n'     'VER UNTIL BYE BEGIN ELSE THEN IF \ ( WORDS .S DEPTH HEX DECIMAL SPACE CR QUIT INTERPRET NUMBER . SW? LED! IMMEDIATE ; : CREATE WORD FIND ] [ ALLOT C, , BASE STATE LATEST HERE EXECUTE C! C@ ! @ R@ R> >R OVER SWAP DUP DROP 0= < = XOR OR AND /MOD - * + EXIT KEY EMIT ok 0 ok'

    echo "--- Per-word stack balance ---"
    check "CR no leak"       'DEPTH .\nCR\nDEPTH .\n'       '0 ok ok 0 ok'
    check "SPACE no leak"    'DEPTH .\nSPACE\nDEPTH .\n'    '0 ok ok 0 ok'
    check "EMIT no leak"     '65 EMIT\nDEPTH .\n'           'A ok 0 ok'
    echo "  SKIP: KEY (needs interactive input)"
    check "+ balance"        '1 2 + DEPTH .\n'               '1 ok'
    check "- balance"        '5 3 - DEPTH .\n'               '1 ok'
    check "AND balance"      '7 3 AND DEPTH .\n'             '1 ok'
    check "OR balance"       '5 3 OR DEPTH .\n'              '1 ok'
    check "XOR balance"      '5 3 XOR DEPTH .\n'             '1 ok'
    check "= true"           '3 3 = .\n'                     '-1 ok'
    check "= false"          '3 4 = .\n'                     '0 ok'
    check "< true"           '2 5 < .\n'                     '-1 ok'
    check "< false"          '5 2 < .\n'                     '0 ok'
    check "0= true"          '0 0= .\n'                      '-1 ok'
    check "0= false"         '7 0= .\n'                      '0 ok'
    check ">R R>"            '99 >R R> .\n'                   '99 ok'
    check "R@"               '99 >R R@ . R> DROP\n'          '99 ok'
    check "@ !"              'HERE @ HERE @ = .\n'           '-1 ok'
    check "C@ C!"            'HERE @ 99 OVER C! C@ .\n'     '99 ok'
    check "LED! no leak"     '1 LED!\nDEPTH .\n'            'ok 0 ok'
    check "SW? released"     'SW? .\n'                       '1 ok'
    check "SW? no leak"      'DEPTH .\nSW? DROP\nDEPTH .\n' '0 ok ok 0 ok'
    check "NUMBER no leak"   '42\nDEPTH .\n'                'ok 1 ok'
    echo "  SKIP: BYE (halts CPU)"

    echo "--- Control flow ---"
    check "IF true"          ': T -1 IF 65 EMIT THEN ; T\n'   'A ok'
    check "IF false"         ': F 0 IF 65 EMIT THEN ; F\n'    'ok'
    check "IF/ELSE true"     ': D -1 IF 65 EMIT ELSE 66 EMIT THEN ; D\n'  'A ok'
    check "IF/ELSE false"    ': E 0 IF 65 EMIT ELSE 66 EMIT THEN ; E\n'   'B ok'
    check "BEGIN/UNTIL"      ': UP 1 BEGIN DUP . 1 + DUP 4 = UNTIL DROP ; UP\n'  '1 2 3 ok'

    echo "--- Version ---"
    check "VER"              'VER\n'    'COR24 Forth v0. ok'

    echo "--- Error handling ---"
    check "unknown word"  'FOO\n'  '? ok'

    echo "--- WORDS ---"
    local_words=$($RUN -u 'WORDS\n' -n 5000000 2>&1 | grep "^UART output:" -A 20 | tr '\n' ' ' | sed-rs -e 's/.*UART output: //' -e 's/Executed.*//')
    if echo "$local_words" | grep -q "EMIT" && echo "$local_words" | grep -q "DUP" && echo "$local_words" | grep -q "LED!"; then
      echo "  PASS: WORDS contains expected entries"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: WORDS output missing expected entries"
      FAIL=$((FAIL + 1))
    fi

    echo ""
    echo "=== Results: $PASS passed, $FAIL failed ==="
    [ "$FAIL" -eq 0 ] && exit 0 || exit 1
    ;;

  demo)
    echo "=== sw-cor24-forth Forth Demo ==="
    echo ""

    run_line() {
      local input="$1"
      local display="${input//\\n/}"
      local output
      output=$($RUN -u "$input" -n 5000000 2>&1 | grep "^UART output:" -A 20 | tr '\n' ' ' | sed-rs -e 's/.*UART output: //' -e 's/Executed.*//' -e 's/  */ /g' -e 's/^ //;s/ $//')
      printf "  %-25s → %s\n" "$display" "$output"
    }

    echo "Arithmetic:"
    run_line '1 .\n'
    run_line '2 3 + .\n'
    run_line '10 3 - .\n'
    run_line '-7 .\n'

    echo ""
    echo "Stack inspection:"
    run_line '1 2 3 .S\n'
    run_line 'DEPTH .\n'
    run_line '1 2 3 DEPTH .\n'

    echo ""
    echo "Hex mode:"
    run_line 'HEX FF . DECIMAL\n'
    run_line 'HEX A0 . DECIMAL\n'

    echo ""
    echo "LED control:"
    led_on=$($RUN -u '1 LED!\n' -n 5000000 --dump 2>&1 | grep "FF0000 LED")
    led_off=$($RUN -u '0 LED!\n' -n 5000000 --dump 2>&1 | grep "FF0000 LED")
    printf "  %-25s → %s\n" "1 LED!" "$(echo "$led_on" | sed-rs -e 's/.*LED: */LED: /')"
    printf "  %-25s → %s\n" "0 LED!" "$(echo "$led_off" | sed-rs -e 's/.*LED: */LED: /')"

    echo ""
    echo "Dictionary:"
    words=$($RUN -u 'WORDS\n' -n 5000000 2>&1 | grep "^UART output:" -A 20 | tr '\n' ' ' | sed-rs -e 's/.*UART output: //' -e 's/  ok.*//')
    echo "  WORDS → $words"

    echo ""
    echo "Error handling:"
    run_line 'FOO\n'

    echo ""
    echo "To start an interactive REPL: ./demo.sh repl"
    ;;

  *)
    echo "Usage: ./demo.sh [demo|repl|test]"
    exit 1
    ;;
esac
