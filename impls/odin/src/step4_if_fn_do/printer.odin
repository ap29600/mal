package mal

import "core:fmt"
import "core:strings"


print :: proc (node: Ast, housekeep := true, print_readably := true) -> string { 
  using strings

  @(static)
  b := Builder{}
  defer if housekeep do b = {}
  if housekeep { init_builder(&b) }

  switch value in node {
    case bool: write_string(&b, value ? "true" : "false")
    case int: write_int(&b, value)
    case string: 
    if print_readably { 
      write_escaped(&b, value) 
    } else { 
      write_string(&b, value) 
    }
    case Symbol: write_string(&b, string(value))
    case Keyword: fmt.sbprintf(&b, ":{}", string(value))
    case List:
    write_string(&b, "(")
    for elem, i in value { 
      print(elem, false, print_readably) 
      if i < len(value) - 1 { write_string(&b, " ") }
    }
    write_string(&b, ")")
    case Map: 
    write_string(&b, "{")
    for elem, i in value { 
      print(elem, false, print_readably) 
      if i < len(value) - 1 { write_string(&b, " ") }
    }
    write_string(&b, "}")
    case Vector: 
    write_string(&b, "[")
    for elem, i in value { 
      print(elem, false, print_readably) 
      if i < len(value) - 1 { write_string(&b, " ") }
    }
    write_string(&b, "]")
    case ^FunctionType:
    write_string(&b, "#<function>")
    case:
    write_string(&b, "nil")
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
