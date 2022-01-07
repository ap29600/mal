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
    if line_len, errno := os.read(os.stdin, line_buffer[:]); errno == 0  && line_len > 0 {
      input_string := string(line_buffer[:line_len])
      fmt.println(rep(input_string))
    } else {
      break
    }
  }

  deinit(&reader)
}

rep :: proc (s: string) -> string { 
  in_ast, ok_read := read(s)
  if !ok_read { return reader_error_string }
  out_ast, err_eval := eval(in_ast)
  if err_eval != .None { fmt.println(err_eval) }
  return print(out_ast)
}

Symbol       :: distinct string
Keyword      :: distinct string
Map          :: distinct []Ast
List         :: distinct []Ast
Vector       :: distinct []Ast
FunctionType :: #type proc(List)->(Ast, EvalError)

Ast :: union {
  int, 
  string,
  Symbol,
  Keyword,
  List,
  Map,
  Vector,
  FunctionType,
}
