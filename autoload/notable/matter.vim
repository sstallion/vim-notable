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

const s:list_pattern = notable#util#pattern('^\[(.*)\]$')

const s:list_val_pattern = notable#util#pattern(
      \ '^\s*(%(''%(''''|[^''])*'')|%([^'',][^,]*))\s*%(,|$)')

const s:matter_pattern = notable#util#pattern('^([^:]+):(.*)$')

const s:quote_pattern = notable#util#pattern('^''(.*)''$')

const s:quote_val_pattern = notable#util#literal_pattern(
      \ '\%(\^\[-!@%&*|''>?]\)\|\[`#{}[\]:,]')

const s:timestamp_format = '%FT%T'  " cf. strftime()

const s:timestamp_pattern = notable#util#pattern(
      \ '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.\d{3})Z$')

function! s:list_trim(val) abort
  let [match, val ; _] = notable#util#matchlist(
        \ trim(a:val), s:list_pattern)
  if empty(match)
    throw 'notable: Invalid list: ' . a:val
  endif
  return val
endfunction

function! s:list_split(val) abort
  let list = []
  let [idx, str] = [0, s:list_trim(a:val)]
  while idx < strlen(str)
    let [match, val ; _] = notable#util#matchlist(
          \ str[idx:], s:list_val_pattern)
    let idx += strlen(match)
    call add(list, val)
  endwhile
  return list
endfunction

function! notable#matter#encode_bool(val) abort
  return a:val ? 'true' : v:none
endfunction

function! notable#matter#encode_list(val) abort
  let list = copy(a:val)
  call map(list, {_, val -> notable#matter#encode_string(val)})
  call filter(list, {_, val -> !empty(val)})
  if empty(list)
    return v:none
  endif
  return printf("[%s]", join(sort(list), ', '))
endfunction

function! notable#matter#encode_string(val) abort
  let str = trim(a:val)
  if empty(str)
    return v:none
  endif
  if match(str, s:quote_val_pattern) == -1
    return str
  endif
  " Quoted strings must have embedded single quotes doubled:
  return printf("'%s'", substitute(str, "'", "''", 'g'))
endfunction

function! notable#matter#encode_timestamp(val) abort
  let seconds = float2nr(a:val)
  let fraction = fmod(a:val, 1.0)

  " Canonical timestamps are specified in UTC; $TZ must be overridden to
  " inform strftime() and restored.
  let save_TZ = $TZ
  let $TZ = 'UTC'
  try
    return notable#matter#encode_string(printf("%s.%03dZ",
          \ strftime(s:timestamp_format, seconds), float2nr(fraction*1000.0)))
  finally
    let $TZ = save_TZ
  endtry
endfunction

" Notable is particular about the order in which front matter appears.
" For compatibility, ordering is preserved when encoding mappings.
const s:encoders = [
      \   ['attachments', function('notable#matter#encode_list')],
      \   ['favorited', function('notable#matter#encode_bool')],
      \   ['pinned', function('notable#matter#encode_bool')],
      \   ['tags', function('notable#matter#encode_list')],
      \   ['title', function('notable#matter#encode_string')],
      \   ['created', function('notable#matter#encode_timestamp')],
      \   ['modified', function('notable#matter#encode_timestamp')],
      \ ]

function! notable#matter#encode(matter) abort
  let lines = []
  for [key, Encode] in s:encoders
    if has_key(a:matter, key)
      let val = Encode(a:matter[key])
      " Notable strips mappings with empty values. For compatibility,
      " empty values are stripped. See empty().
      if !empty(val)
        call add(lines, printf("%s: %s", key, val))
      endif
    endif
  endfor
  return lines
endfunction

function! notable#matter#decode_bool(val) abort
  return trim(a:val) ==? 'true' ? v:true : v:false
endfunction

function! notable#matter#decode_list(val) abort
  let list = s:list_split(a:val)
  call map(list, {_, val -> notable#matter#decode_string(val)})
  call filter(list, {_, val -> !empty(val)})
  return sort(list)
endfunction

function! notable#matter#decode_string(val) abort
  let str = trim(a:val)
  let [match, val ; _] = notable#util#matchlist(
        \ str, s:quote_pattern)
  if !empty(match)
    return substitute(val, "''", "'", 'g')
  endif
  return str
endfunction

function! notable#matter#decode_timestamp(val) abort
  let [match, seconds, fraction ; _] = notable#util#matchlist(
        \ notable#matter#decode_string(a:val), s:timestamp_pattern)
  if empty(match)
    throw 'notable: Invalid timestamp: ' . a:val
  endif

  " Canonical timestamps are specified in UTC; $TZ must be overridden to
  " inform strptime() and restored.
  let save_TZ = $TZ
  let $TZ = 'UTC'
  try
    return strptime(s:timestamp_format, seconds) + str2float(fraction)
  finally
    let $TZ = save_TZ
  endtry
endfunction

const s:decoders = {
      \   'attachments': function('notable#matter#decode_list'),
      \   'favorited': function('notable#matter#decode_bool'),
      \   'pinned': function('notable#matter#decode_bool'),
      \   'tags': function('notable#matter#decode_list'),
      \   'title': function('notable#matter#decode_string'),
      \   'created': function('notable#matter#decode_timestamp'),
      \   'modified': function('notable#matter#decode_timestamp'),
      \ }

function! notable#matter#decode(lines) abort
  let matter = {}
  for line in a:lines
    let [match, key, val ; _] = notable#util#matchlist(
          \ trim(line), s:matter_pattern)
    if empty(match)
      throw 'notable: Invalid mapping: ' . line
    endif
    if has_key(s:decoders, key)
      let Decode = s:decoders[key]
      let matter[key] = Decode(val)
    endif
  endfor
  " Notable strips mappings with empty values. For compatibility,
  " empty values are stripped. See empty().
  return filter(matter, {_, val -> !empty(val)})
endfunction

function! notable#matter#now() abort
  return reltimefloat(reltime())
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
