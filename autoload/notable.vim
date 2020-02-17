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

let g:notable_config = $HOME . '/' . '.notable.json'

function! notable#config()
  if !exists('s:config')
    let lines = readfile(g:notable_config)
    let s:config = json_decode(lines->join())
  endif
  return s:config
endfunction

function! notable#cwd()
  return notable#config()['cwd']
endfunction

" TODO new file has the following by default:
" ---
" title:
" created:
" modified:
" ---
"
" # title
" <cursor>
" TODO: changing the title changes the filename

let &cpo = s:save_cpo
unlet s:save_cpo
