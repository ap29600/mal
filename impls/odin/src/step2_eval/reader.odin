package mal

import re "regex"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:fmt"
import "core:c"

Reader :: struct {
  regex: re.Regex,
  view: string,
  position: c.int,
  match: re.Regmatch,
}

init :: proc (r: ^Reader, pattern: cstring) -> (string, bool) {
  if err := re.compile(&r.regex, pattern, {.EXTENDED}); err != .NOERROR {
    return re.error_string(err, &r.regex, context.temp_allocator), false
  }
  return "", true
}
deinit :: proc (r: ^Reader) { re.free(&r.regex) }

load_string :: proc (r: ^Reader, s: string) {
  r.view = s
  r.position = 0
  r.match = {}
  next(r)
}

next :: proc (r: ^Reader) -> (string, bool) {
  // return the current token
  result, ok := peek(r)
  if !ok { return "", false }

  // advance
  for go := true; go; {
    go = false
    r.position += r.match.end
    if int(r.position) >= len(r.view) { 
      r.match = {-1, -1}
      return result, ok
    }
    buf := strings.clone_to_cstring(r.view[int(r.position):], context.temp_allocator)

    if re._regexec(&r.regex, buf, 1, &r.match, {}) == .NOMATCH {
      r.match = {-1, -1} 
    } else if strings.contains_rune(" \t\v\n,", rune(r.view[r.position + r.match.start])) >= 0 {
      // throw away bad tokens
      go = true
    }
  }

  return result, ok
}

reader_error_string := "Everything is good."

peek :: proc (r: ^Reader) -> (string, bool) {
  if r.match.start == -1 {
    reader_error_string = "EOL reached while parsing"
    return "", false
  }
  return r.view[r.position + r.match.start: r.position + r.match.end], true
}

read  :: proc (s: string) -> (res: Ast, ok: bool) { 
  load_string(&reader, s)
  return read_form(&reader)
}

quote_symbols := map[string]Symbol {
  "'"  = "quote",
  "`"  = "quasiquote",
  "~"  = "unquote",
  "@"  = "deref",
  "~@" = "splice-unquote",
}

read_form :: proc (r: ^Reader) -> (res: Ast, ok: bool) {
  tok := peek(r) or_return
  switch {
    case tok in quote_symbols: 
    next(r) or_return
    return List(slice.clone([]Ast{quote_symbols[tok], read_form(r) or_return})), true
    case tok == "^":
    next(r) or_return
    metadata := read_form(r) or_return
    object := read_form(r) or_return
    return List(slice.clone([]Ast{Symbol(strings.clone("with-meta")), object, metadata})), true
    case tok == "(": return List(read_list(r) or_return), true
    case tok == "[": return Vector(read_list(r) or_return), true
    case tok == "{": return Map(read_list(r) or_return), true
    case: return read_atom(r)
  }
}

matching := map[u8]u8 {
  ')' = '(',
  ']' = '[',
  '}' = '{',
}
 
read_list :: proc (r: ^Reader) -> (res: []Ast, ok: bool) {
  result  := [dynamic]Ast{}
  opening_token := next(r) or_return [0]
  for tok in peek(r) {
    if tok[0] in matching { break }
    append(&result, read_form(r) or_return) 
  }
  closing_token := next(r) or_return [0]

  if opening_token != matching[closing_token] { 
    reader_error_string = "unbalanced"
    return {}, false 
  }

  return result[:], true
}

read_atom :: proc (r: ^Reader) -> (res: Ast, ok: bool) {
  tok := next(r) or_return
  switch tok[0] {
    case ':':      return Keyword(strings.clone(tok[1:])), true
    case '"':      return validate_and_unescape(tok)
    case '0'..'9': 
    val, ok := strconv.parse_int(tok)
    if !ok { reader_error_string = "invalid int literal" } 
    return val, ok
    case '-':
    if len(tok) > 1 && '0' <= tok[1] && tok[1] <= '9' { 
      val, ok := strconv.parse_int(tok)
      if !ok { reader_error_string = "invalid int literal" } 
      return val, ok 
    } else { 
      return Symbol(strings.clone(tok)), true 
    }
    case: return Symbol(strings.clone(tok)), true
  }
}

escape_map := map[rune]rune {
  'n' = '\n',
  't' = '\t',
}
validate_and_unescape :: proc (s: string) -> (res: string, ok: bool) {
  if len(s) < 2           { reader_error_string = "invalid string literal"; return "", false }
  if s[len(s) - 1] != '"' { reader_error_string = "invalid string literal"; return "", false }

  b := strings.Builder{}
  strings.init_builder(&b)

  escaped := false
  meta_escaped := false

  for r in s[1:len(s) - 1] {
    if !escaped && r == '\\' { escaped = true; continue }
    if escaped {
      strings.write_rune_builder(&b, escape_map[r] or_else r)
      escaped = false
    } else {
      strings.write_rune_builder(&b, r)
    }
  }
  if escaped { reader_error_string = "invalid string literal"; return "", false }
  return strings.to_string(b), true
}

