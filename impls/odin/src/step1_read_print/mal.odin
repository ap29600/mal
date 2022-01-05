package mal

import "core:fmt"
import "core:slice"
import "core:strings"
import "core:intrinsics"
import "core:os"
import c "core:c/libc"

token_regular_expression :: "[[:space:],]+|~@|[][(){}'`~\\^@]|\"([^\"]|\\\\\")*\"|;.*|[^][[:space:]()\\{\\}'`@~,;]+"


line_buffer:= [4096]u8{}
reader := Reader{}

main :: proc () {
  if err, ok := init(&reader, token_regular_expression); !ok { 
    fmt.println(err)
    os.exit(1) 
  }

  for {
    fmt.print("user> ")
    if line_len, errno := os.read(os.stdin, line_buffer[:]); errno == 0  && line_len > 0{
      input_string := string(line_buffer[:line_len])
      fmt.println(rep(input_string))
    } else {
      break
    }
  }

  deinit(&reader)
}

rep :: proc (s: string) -> string{ 
  in_ast, ok_read := read(s)
  if !ok_read { return "unbalanced" }
  out_ast := eval(in_ast)
  return print(out_ast)
}

Symbol :: distinct string
Keyword :: distinct string
Map :: distinct []Ast
List :: distinct []Ast
Vector :: distinct []Ast

Ast :: union #no_nil { 
  int, 
  string,
  Symbol,
  Keyword,
  List,
  Map,
  Vector,
}

read  :: proc (s: string) -> (res: Ast, ok: bool) { 
  load_string(&reader, s)
  return read_form(&reader)
}

eval  :: proc (s: Ast) -> Ast { return s }

print :: proc (node: Ast, housekeep := true) -> string { 
  using strings

  @(static)
  b := Builder{}
  defer if housekeep do b = {}
  if housekeep { init_builder(&b) }

  switch value in node {
    case int: write_int(&b, value)
    case string: write_escaped(&b, value)
    case Symbol: write_string(&b, string(value))
    case Keyword: fmt.sbprintf(&b, ":{}", string(value))
    case List:
    write_string(&b, "(")
    for elem, i in value { 
      print(elem, false) 
      if i < len(value) - 1 { write_string(&b, " ") }
    }
    write_string(&b, ")")
    case Map: 
    write_string(&b, "{")
    for elem, i in value { 
      print(elem, false) 
      if i < len(value) - 1 { write_string(&b, " ") }
    }
    write_string(&b, "}")
    case Vector: 
    write_string(&b, "[")
    for elem, i in value { 
      print(elem, false) 
      if i < len(value) - 1 { write_string(&b, " ") }
    }
    write_string(&b, "]")
  }

  if housekeep do return to_string(b)
  else do return ""
}


write_escaped :: proc (b: ^strings.Builder, s: string) {
  strings.write_rune_builder(b, '"')
  for r in s {
    strings.write_escaped_rune_builder(b, r, '"')
  }
  strings.write_rune_builder(b, '"')
}
