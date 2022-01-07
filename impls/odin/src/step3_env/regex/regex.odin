package regex

import "core:c"
import "core:slice"
foreign import re "system:c"

@(default_calling_convention="c")
foreign re {
  @(link_name="regcomp")
  compile :: proc "c" (preg: ^Regex, pattern: cstring, cflags: Cflags) -> RegexErrorcode ---

  @(link_name="regexec")
  _regexec :: proc "c" (preg: ^Regex, str: cstring, nmatch: c.size_t, pmatch: [^]Regmatch, eflags: Eflags) -> RegexErrorcode ---

  @(link_name="regerror")
  _regerror :: proc(errcode : RegexErrorcode, preg : ^Regex, errbuf : cstring, errbuf_size : c.size_t) -> c.size_t ---;

  @(link_name="regfree")
  free :: proc(preg : ^Regex) ---;
}

error_string :: proc (errcode: RegexErrorcode, preg: ^Regex, allocator := context.allocator) -> string { 
  error_size := _regerror(errcode, preg, nil, 0)
  buffer := make([]u8, error_size)
  _regerror(errcode, preg, cast(cstring)slice.as_ptr(buffer), error_size)
  return string(buffer[:int(error_size) - 1])
}

execute :: proc (preg: ^Regex, str: cstring, matches: []Regmatch, eflags: Eflags) -> RegexErrorcode {
  return _regexec(preg, str, len(matches), slice.as_ptr(matches), eflags)
}

// Regex :: distinct [64]byte
Regex :: struct {
    buffer : rawptr,
    allocated : c.ulong,
    used : c.ulong,
    syntax : c.ulong,
    fastmap : cstring,
    translate : rawptr,
    re_nsub : c.size_t,
    can_be_null : c.uint,
    regs_allocated : c.uint,
    fastmap_accurate : c.uint,
    no_sub : c.uint,
    not_bol : c.uint,
    not_eol : c.uint,
    newline_anchor : c.uint,
};

Cflag :: enum {
  EXTENDED,
  ICASE,
  NEWLINE,
  NOSUB,
}
Cflags :: bit_set[Cflag; c.int]

Eflag :: enum {
  NOTBOL = 1,
  NOTEOL,
  STARTEND,
}
Eflags :: bit_set[Eflag; c.int]

RegexErrorcode :: enum i32 {
  ENOSYS  = -1,
  NOERROR = 0,
  NOMATCH,
  BADPAT,	 
  ECOLLATE, 
  ECTYPE,	 
  EESCAPE,	 
  ESUBREG,	 
  EBRACK,	 
  EPAREN,	 
  EBRACE,	 
  BADBR,
  ERANGE,	 
  ESPACE,	 
  BADRPT,	 
  EEND,
  ESIZE,
  ERPAREN,
}

Regmatch :: struct {start, end: c.int}
