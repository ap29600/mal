package mal

import re "regex"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:fmt"
import "core:c"

Reader :: struct {
  regex: re.Regex,
  loaded_string: string,
  position: c.int,
  buffer_len: c.int,
  match: re.Regmatch,
}

ReadError :: enum {
  None,
  ReachedEOF,
  EmptyLine,
  InvalidLiteral,
  MismatchedDelimiters,
}

init :: proc (r: ^Reader, pattern: cstring) -> (string, bool) {
  if err := re.compile(&r.regex, pattern, {.EXTENDED}); err != .NOERROR {
    return re.error_string(err, &r.regex, context.temp_allocator), false
  }
  return "", true
}

deinit :: proc (r: ^Reader) { re.free(&r.regex) }

load_string :: proc (r: ^Reader, s: string) {
  delete(r.loaded_string)
  r.loaded_string = string(strings.clone_to_cstring(s)) // the underlying buffer is null-terminated
  r.position = 0
  r.match = {}
  next(r)
}

next :: proc (r: ^Reader) -> (tok: string, err: ReadError) {
  // return the current token
  result := peek(r) or_return

  when ODIN_DEBUG { fmt.println(">>>", result) }

  // advance
  for go := true; go; {
    go = false
    r.position += r.match.end
    if int(r.position) >= len(r.loaded_string) { r.match = {-1, -1}; return result, .None }

    // this is ok because the underlying data is a cstring
    buf := cast(cstring)slice.as_ptr(transmute([]u8)r.loaded_string[r.position:])

    if re._regexec(&r.regex, buf, 1, &r.match, {}) == .NOMATCH { r.match = {-1, -1} } 
    else if strings.contains_rune(" \t\v\n,", rune(r.loaded_string[r.position + r.match.start])) >= 0 { go = true }
  }

  return result, .None
}


peek :: proc (r: ^Reader, silent := false) -> (tok: string, err: ReadError) {
  if r.match.start == -1 { return "", .ReachedEOF }
  return r.loaded_string[r.position + r.match.start: r.position + r.match.end], .None
}

read  :: proc (s: string) -> (res: Ast, err: ReadError) { 
  load_string(&reader, s)
  if first, err := peek(&reader); err == .ReachedEOF { return nil, .EmptyLine }
  return read_form(&reader)
}

quote_symbols := map[string]Symbol {
  "'"  = "quote",
  "`"  = "quasiquote",
  "~"  = "unquote",
  "@"  = "deref",
  "~@" = "splice-unquote",
}

read_form :: proc (r: ^Reader) -> (res: Ast, err: ReadError) {
  tok := peek(r) or_return
  switch {
    case tok in quote_symbols: 
    next(r) or_return
    return List(slice.clone([]Ast{quote_symbols[tok], read_form(r) or_return})), .None
    case tok == "^":
    next(r) or_return
    metadata := read_form(r) or_return
    object := read_form(r) or_return
    return List(slice.clone([]Ast{Symbol(strings.clone("with-meta")), object, metadata})), .None
    case tok == "(": return List(read_list(r) or_return),   .None
    case tok == "[": return Vector(read_list(r) or_return), .None
    case tok == "{": return Map(read_list(r) or_return),    .None
    case: return read_atom(r)
  }
}

matching := map[u8]u8 {
  ')' = '(',
  ']' = '[',
  '}' = '{',
}
 
read_list :: proc (r: ^Reader) -> (res: []Ast, err: ReadError) {
  result  := [dynamic]Ast{}
  opening_token := next(r) or_return [0]

  for tok, err := peek(r); err == .None ; tok, err = peek(r) {
    if tok[0] in matching { break }
    append(&result, read_form(r) or_return) 
  }

  closing_token := next(r) or_return [0]

  if opening_token != matching[closing_token] { return nil, .MismatchedDelimiters }

  return result[:], .None
}

read_atom :: proc (r: ^Reader) -> (res: Ast, err: ReadError) {
  tok := next(r) or_return
  switch tok[0] {
    case ':':      return Keyword(strings.clone(tok[1:])), .None
    case '"':      return validate_and_unescape(tok)
    case '0'..'9': 
    val, ok := strconv.parse_int(tok)
    if !ok { return nil, .InvalidLiteral} 
    return val, .None
    case '-':
    if len(tok) > 1 && '0' <= tok[1] && tok[1] <= '9' { 
      val, ok := strconv.parse_int(tok)
      if !ok {  return nil, .InvalidLiteral } 
      return val, .None
    } else { 
      return Symbol(strings.clone(tok)), .None
    }
    case: 
    switch tok {
      case "nil":   return nil,   .None
      case "false": return false, .None
      case "true":  return true,  .None
      case: return Symbol(strings.clone(tok)), .None
    }
  }
}

escape_map := map[rune]rune {
  'n' = '\n',
  't' = '\t',
}

validate_and_unescape :: proc (s: string) -> (res: string, err: ReadError) {
  if len(s) < 2           { return "", .InvalidLiteral }
  if s[len(s) - 1] != '"' { return "", .InvalidLiteral }

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
  if escaped { return "", .InvalidLiteral }
  return strings.to_string(b), .None
}

