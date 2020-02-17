" Copyright (c) 2020, Steven Stallion
" All rights reserved.
"
" Redistribution and use in source and binary forms, with or without
" modification, are permitted provided that the following conditions
" are met:
" 1. Redistributions of source code must retain the above copyright
"    notice, this list of conditions and the following disclaimer.
" 2. Redistributions in binary form must reproduce the above copyright
"    notice, this list of conditions and the following disclaimer in the
"    documentation and/or other materials provided with the distribution.
"
" THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
" ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
" IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
" ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
" FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
" DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
" OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
" HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
" LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
" OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
" SUCH DAMAGE.

let s:save_cpo = &cpo
set cpo&vim

let s:tc = unittest#testcase#new('notable#matter')

function! s:tc.test_encode_bool()
  call self.assert_equal(notable#matter#encode_bool(v:true), 'true')
  call self.assert_equal(notable#matter#encode_bool(v:false), v:none)
endfunction

function! s:tc.test_encode_list()
  let expected = [
        \   [[]                  , v:none        ],
        \   [['']                , v:none        ],
        \   [['a']               , '[a]'         ],
        \   [['a b', 'c']        , '[a b, c]'    ],
        \   [['a', 'b', 'c', 'd'], '[a, b, c, d]'],
        \   [['d', 'c', 'b', 'a'], '[a, b, c, d]'],
        \ ]
  for [input, output] in expected
    call self.assert_equal(notable#matter#encode_list(input), output)
  endfor
endfunction

function! s:tc.test_encode_string()
  let expected = [
        \   [''    , v:none],
        \   ['abcd', 'abcd'],
        \ ]
  for [input, output] in expected
    call self.assert_equal(notable#matter#encode_string(input), output)
  endfor
endfunction

function! s:tc.test_encode_string_embedded_quote()
  let expected = [
        \   ["'a'b", "'''a''b'"],
        \   ["!a'b", "'!a''b'" ],
        \   ["a'b" , "a'b"     ],
        \   ["ab'" , "ab'"     ],
        \ ]
  for [input, output] in expected
    call self.assert_equal(notable#matter#encode_string(input), output)
  endfor
endfunction

function! s:tc.test_encode_string_leading_special()
  for special in ['-', '&', '?', '|', '>', '!', '%', '@', "'"]
    " A special case exists for leading single quotes; if present, the
    " the quote should be doubled prior to quoting the string:
    let input = special . 'x'
    if special == "'"
      let output = "'''x'"
    else
      let output = printf("'%s'", input)
    endif
    call self.assert_equal(notable#matter#encode_string(input), output)
  endfor
endfunction

function! s:tc.test_encode_string_contains_special()
  for special in ['{', '}', '[', ']', '#', ':', ',', '`']
    let input = 'x' . special
    let output = printf("'%s'", input)
    call self.assert_equal(notable#matter#encode_string(input), output)
  endfor
endfunction

function! s:tc.test_encode_string_trim()
  let expected = [
        \   ['    ', v:none],
        \   [' abc', 'abc' ],
        \   ['abc ', 'abc' ],
        \   ['ab c', 'ab c'],
        \ ]
  for [input, output] in expected
    call self.assert_equal(notable#matter#encode_string(input), output)
  endfor
endfunction

function! s:tc.test_encode_timestamp()
  let expected = [
        \   [         0.0     , "'1970-01-01T00:00:00.000Z'"],
        \   [1321020102.123456, "'2011-11-11T14:01:42.123Z'"],
        \   [1421410509.456123, "'2015-01-16T12:15:09.456Z'"],
        \ ]
  for [input, output] in expected
    let save_TZ = $TZ
    let $TZ = 'XXX'
    try
      call self.assert_equal(notable#matter#encode_timestamp(input), output)
      call self.assert_equal('XXX', $TZ)  " ensure TZ preserved
    finally
      let $TZ = save_TZ
    endtry
  endfor
endfunction

function! s:tc.test_encode()
  let input = {
        \   'attachments': [],
        \   'favorited': v:true,
        \   'pinned': v:false,
        \   'tags': ['tag1', 'tag2'],
        \   'title': 'Working Title',
        \   'created': 1321020102.000000,
        \   'modified': 1421410509.000000,
        \ }
  let output = [
        \   "favorited: true",
        \   "tags: [tag1, tag2]",
        \   "title: Working Title",
        \   "created: '2011-11-11T14:01:42.000Z'",
        \   "modified: '2015-01-16T12:15:09.000Z'",
        \ ]
  call self.assert_equal(notable#matter#encode(input), output)
endfunction

function! s:tc.test_encode_skip_unknown()
  let expected = [
        \   [{'unknown1': 'abcd'}, []                 ],
        \   [{'favorited': v:true ,
        \     'unknown2': 'dcba'}, ['favorited: true']]
        \ ]
  for [input, output] in expected
    call self.assert_equal(notable#matter#encode(input), output)
  endfor
endfunction

function! s:tc.test_decode_bool()
  call self.assert_equal(notable#matter#decode_bool('true'), v:true)
  call self.assert_equal(notable#matter#decode_bool('tRuE'), v:true)
  call self.assert_equal(notable#matter#decode_bool('false'), v:false)
  call self.assert_equal(notable#matter#decode_bool('xxxxx'), v:false)
endfunction

function! s:tc.test_decode_list()
  let expected = [
        \   ['[]'          , []                  ],
        \   ['[a]'         , ['a']               ],
        \   ['[a b, c]'    , ['a b', 'c']        ],
        \   ['[a, b, c, d]', ['a', 'b', 'c', 'd']],
        \   ['[d, c, b, a]', ['a', 'b', 'c', 'd']],
        \ ]
  for [input, output] in expected
    call self.assert_equal(output, notable#matter#decode_list(input))
  endfor
endfunction

function! s:tc.test_decode_list_quoted()
  let expected = [
        \   ["['a, b, c, d']", ['a, b, c, d']],
        \   ["['a', 'b']"    , ['a', 'b']    ],
        \   ["[a, 'b, c']"   , ['a', 'b, c'] ],
        \   ["[a, 'b, ''']"  , ['a', "b, '"] ],
        \ ]
  for [input, output] in expected
    call self.assert_equal(output, notable#matter#decode_list(input))
  endfor
endfunction

function! s:tc.test_decode_string()
  let expected = [
        \   [''    , ''    ],
        \   ['abcd', 'abcd'],
        \ ]
  for [input, output] in expected
    call self.assert_equal(output, notable#matter#decode_string(input))
  endfor
endfunction

function! s:tc.test_decode_string_embedded_quote()
  let expected = [
        \   ["'!a''b'", "!a'b"],
        \   ["a'b"    , "a'b" ],
        \   ["ab'"    , "ab'" ],
        \ ]
  for [input, output] in expected
    call self.assert_equal(output, notable#matter#decode_string(input))
  endfor
endfunction

function! s:tc.test_decode_string_leading_special()
  for special in ['-', '&', '?', '|', '>', '!', '%', '@', "'"]
    " A special case exists for leading single quotes; if present, the
    " the quote should be undoubled prior to unquoting the string:
    let output = special . 'x'
    if special == "'"
      let input = "'''x'"
    else
      let input = printf("'%s'", output)
    endif
    call self.assert_equal(output, notable#matter#decode_string(input))
  endfor
endfunction

function! s:tc.test_decode_string_contains_special()
  for special in ['`', '#', '{', '}', '[', ']', ':', ',']
    let output = 'x' . special
    let input = printf("'%s'", output)
    call self.assert_equal(output, notable#matter#decode_string(input))
  endfor
endfunction

function! s:tc.test_decode_timestamp()
  let expected = [
        \   ["'1970-01-01T00:00:00.000Z'",          0.0     ],
        \   ["'2011-11-11T14:01:42.123Z'", 1321020102.123000],
        \   ["'2015-01-16T12:15:09.456Z'", 1421410509.456000],
        \ ]
  for [input, output] in expected
    let save_TZ = $TZ
    let $TZ = 'XXX'
    try
      call self.assert_equal(output, notable#matter#decode_timestamp(input))
      call self.assert_equal('XXX', $TZ)  " ensure TZ preserved
    finally
      let $TZ = save_TZ
    endtry
  endfor
endfunction

function! s:tc.test_decode_timestamp_invalid()
  let save_TZ = $TZ
  let $TZ = 'XXX'
  try
    call self.assert_throw('notable: Invalid timestamp',
          \ "call notable#matter#decode_timestamp('invalid')")
    call self.assert_equal('XXX', $TZ)  " ensure TZ preserved
  finally
    let $TZ = save_TZ
  endtry
endfunction

function! s:tc.test_decode()
  let input = [
        \   "attachments: []",
        \   "favorited: true",
        \   "pinned: false",
        \   "tags: [tag1, tag2]",
        \   "title: Working Title",
        \   "created: '2011-11-11T14:01:42.000Z'",
        \   "modified: '2015-01-16T12:15:09.000Z'",
        \ ]
  let output = {
        \   'favorited': v:true,
        \   'tags': ['tag1', 'tag2'],
        \   'title': 'Working Title',
        \   'created': 1321020102.000000,
        \   'modified': 1421410509.000000,
        \ }
  call self.assert_equal(output, notable#matter#decode(input))
endfunction

function! s:tc.test_decode_invalid()
  call self.assert_throw('notable: Invalid mapping',
        \ "call notable#matter#decode(['invalid'])")
endfunction

function! s:tc.test_decode_encode()
  let output = [
        \   "favorited: true",
        \   "tags: [tag1, tag2]",
        \   "title: Working Title",
        \   "created: '2011-11-11T14:01:42.000Z'",
        \   "modified: '2015-01-16T12:15:09.000Z'",
        \ ]
  call self.assert_equal(output,
        \ notable#matter#encode(notable#matter#decode(output)))
endfunction

function! s:tc.test_now()
  let time = notable#matter#now()
  sleep 100m  " ensure timestamps differ
  call self.assert_not_equal(time, notable#matter#now())
endfunction

unlet s:tc

let &cpo = s:save_cpo
unlet s:save_cpo
